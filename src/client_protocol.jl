# Client logic deals with handling control frames, user requesting to send frames, state.
# The ClientProtocol type is defined below entirely synchronously. It takes input via the `handle()`
# function, which is defined for the different input types below. It performs internal logic and
# produces a call to its outbound interface.
#
# The outbound interface is composed of two abstract types `WebSocketHandler` and
# `AbstractWriterTaskProxy`. The concrete implementations will be `TaskProxy` objects, which will
# store the calls (function and arguments) and call it on a target object in another coroutine. This
# means that as long as the channels don't block, the logic will be performed concurrently with the
# the callbacks and writing to the network. This is important because the logic might have to respond
# to ping requests in a timely manner, which it might not be able to do if the callbacks block.
#
# For testing purposes the abstract outbound interface can be replaced with mock objects. This lets us
# test the logic of the WebSocket synchronously, without any asynchronicity or concurrency
# complicating things.

export ClientProtocol

#
# ClientProtocol
#

"Type for the logic of a client WebSocket."
mutable struct ClientProtocol <: AbstractClientProtocol
	# The object to which callbacks should be made. This proxy will make the callbacks
	# asynchronously.
	handler::WebSocketHandler
	# Writes frames to the socket, according to the framing details.
	framewriter::FrameWriter
	# Keeps track of when a pong is expected to be received from the server.
	ponger::AbstractPonger
	# Here we keep data collected when we get a message made up of multiple frames.
	buffer::Vector{UInt8}
	# This stores the type of the multiple frame message. This is the opcode of the first frame,
	# as the following frames have the OPCODE_CONTINUATION opcode.
	buffered_type::Opcode
	# This function cleans up the client when the connection is closed.
	client_cleanup::Function
	# Is the connection close behaviour if a close has been initiated
	closebehaviour::Nullable{ClosingBehaviour}
end

ClientProtocol(handler::WebSocketHandler,
			framewriter::FrameWriter,
	        ponger::AbstractPonger,
			client_cleanup::Function) =
	ClientProtocol(handler, framewriter, ponger, Vector{UInt8}(), OPCODE_TEXT, client_cleanup, Nullable{ClosingBehaviour}())

"The state of the connection."
function protocolstate(p::ClientProtocol)
	if !isnull(p.closebehaviour)
		protocolstate(get(p.closebehaviour))
	else
		STATE_OPEN
	end
end

# Requirement
# @5_5_1-4 No frames after Close frame
# @7_2_1-3 Abnormal client initiated closure
#
# By design, we only send text, binary, and ping frames when state is open. When a ClosingBehaviour
# is in effect, then the state is not open. Therefore, we do not send any close frames during a
# connection close.

"Send a single text frame."
function handle(logic::ClientProtocol, req::SendTextFrame)
	if protocolstate(logic) == STATE_OPEN
		send(logic.framewriter, req.isfinal, req.opcode, req.data)
	end
end

"Send a single binary frame."
function handle(logic::ClientProtocol, req::SendBinaryFrame)
	if protocolstate(logic) == STATE_OPEN
		send(logic.framewriter, req.isfinal, req.opcode, req.data)
	end
end

function handle(logic::ClientProtocol, req::ClientPingRequest)
	if protocolstate(logic) == STATE_OPEN
		ping_sent(logic.ponger)
		send(logic.framewriter, true, OPCODE_PING, b"")
	end
end

function handle(p::ClientProtocol, ::PongMissed)
	failtheconnection(p, CLOSE_STATUS_ABNORMAL_CLOSE; reason="Missed expected pongs")
	p.client_cleanup()
end

"Handle a user request to close the WebSocket."
function handle(logic::ClientProtocol, req::CloseRequest)
	if protocolstate(logic) != STATE_OPEN
		closebehaviour = get(logic.closebehaviour)
		clientprotocolinput(closebehaviour, req)
		return
	end

	closebehaviour = ClientInitiatedCloseBehaviour(logic.framewriter, logic.handler)
	logic.closebehaviour = Nullable{ClosingBehaviour}(closebehaviour)
	closetheconnection(closebehaviour)
end

"The underlying socket was closed. This is sent by the reader."
function handle(logic::ClientProtocol, socketclosed::SocketClosed)
	if protocolstate(logic) != STATE_OPEN
		closebehaviour = get(logic.closebehaviour)
		clientprotocolinput(closebehaviour, socketclosed)
		logic.client_cleanup()
		return
	end

	# Requirement
	# @7_2_1-2 Underlying connection is lost

	failtheconnection(logic, CLOSE_STATUS_ABNORMAL_CLOSE; issocketprobablyup=false)

	logic.client_cleanup()
end

iscontrolframe(frame::Frame) = frame.opcode in [OPCODE_CLOSE, OPCODE_PING, OPCODE_PONG]

"Handle a frame from the server."
function handle(logic::ClientProtocol, req::FrameFromServer)
	# Requirement
	# @6_2-3 Receiving a data frame

	if protocolstate(logic) != STATE_OPEN
		closebehaviour = get(logic.closebehaviour)
		clientprotocolinput(closebehaviour, req)
		return
	end

	# The client must close the connection if it receives a masked frame from the server.
	if req.frame.ismasked
		failtheconnection(logic, CLOSE_STATUS_PROTOCOL_ERROR; reason="Server sent a masked frame")
		return
	end

	# If a reserved bit is set, and no extensions are negotiated, then the client must fail the
	# connection.
	# Note: We do not support extensions yet, so by design no extension has been negotiated.
	if req.frame.rsv1 || req.frame.rsv2 || req.frame.rsv3
		failtheconnection(logic, CLOSE_STATUS_PROTOCOL_ERROR; reason="A reserved bit was set")
		return
	end

	# If a fragmented control frame is received, then the client must fail the connection.
	if iscontrolframe(req.frame) && !req.frame.fin
		failtheconnection(logic, CLOSE_STATUS_PROTOCOL_ERROR; reason="A fragmented control frame was received")
		return
	end

	# If a control frame with payload size > 125 bytes is received, then the client must fail the
	# connection.
	if iscontrolframe(req.frame) && length(req.frame.payload) > 125
		failtheconnection(logic, CLOSE_STATUS_PROTOCOL_ERROR; reason="Control frame payload too large")
		return
	end

	if req.frame.opcode == OPCODE_CLOSE
		handle_close(logic, req.frame)
	elseif req.frame.opcode == OPCODE_PING
		handle_ping(logic, req.frame.payload)
	elseif req.frame.opcode == OPCODE_PONG
		handle_pong(logic, req.frame.payload)
	elseif req.frame.opcode == OPCODE_TEXT
		handle_text(logic, req.frame)
	elseif req.frame.opcode == OPCODE_BINARY
		handle_binary(logic, req.frame)
	elseif req.frame.opcode == OPCODE_CONTINUATION
		handle_continuation(logic, req.frame)
	end
end

#
# Internal closing methods
#

function failtheconnection(p::ClientProtocol, status::CloseStatus;
						   issocketprobablyup=true,
						   reason::String = "")
	fail = FailTheConnectionBehaviour(p.framewriter, p.handler, status;
									  issocketprobablyup = issocketprobablyup,
									  reason = reason)
	p.closebehaviour = Nullable{ClosingBehaviour}(fail)
	closetheconnection(fail)
end

#
# Internal handle functions
#

function handle_close(p::ClientProtocol, frame::Frame)
	# TODO Read actual close status
	closebehaviour = ServerInitiatedCloseBehaviour(p.framewriter, p.handler, CLOSE_STATUS_NORMAL)
	p.closebehaviour = Nullable{ClosingBehaviour}(closebehaviour)
	closetheconnection(closebehaviour)
end

function handle_ping(logic::ClientProtocol, payload::Vector{UInt8})
	send(logic.framewriter, true, OPCODE_PONG, payload)
end

function handle_pong(logic::ClientProtocol, ::Vector{UInt8})
	pong_received(logic.ponger)
end

function handle_text(logic::ClientProtocol, frame::Frame)
	if frame.fin
		text = String(frame.payload)
		if !isvalid(text)
			failtheconnection(logic, CLOSE_STATUS_INCONSISTENT_DATA; reason="Invalid UTF-8")
			return
		end
		on_text(logic.handler, String(frame.payload))
	else
		start_buffer(logic, frame.payload, OPCODE_TEXT)
	end
end

function handle_binary(logic::ClientProtocol, frame::Frame)
	if frame.fin
		on_binary(logic.handler, frame.payload)
	else
		start_buffer(logic, frame.payload, OPCODE_BINARY)
	end
end

# TODO: What if we get a binary/text frame before we get a final continuation frame?
# Answer: Fail the connection. It's in the specification.
function handle_continuation(logic::ClientProtocol, frame::Frame)
	buffer(logic, frame.payload)
	if frame.fin
		if logic.buffered_type == OPCODE_TEXT
			text = String(logic.buffer)
			if !isvalid(text)
				failtheconnection(logic, CLOSE_STATUS_INCONSISTENT_DATA; reason="Multiframe message with invalid UTF-8")
				return
			end
			on_text(logic.handler, text)
		elseif logic.buffered_type == OPCODE_BINARY
			on_binary(logic.handler, logic.buffer)
			logic.buffer = Vector{UInt8}()
		end
	end
end

function start_buffer(logic::ClientProtocol, payload::Vector{UInt8}, opcode::Opcode)
	logic.buffered_type = opcode
	logic.buffer = copy(payload)
end

function buffer(logic::ClientProtocol, payload::Vector{UInt8})
	append!(logic.buffer, payload)
end

#
# Utilities
#

function masking!(input::Vector{UInt8}, mask::Vector{UInt8})
	m = 1
	for i in 1:length(input)
		input[i] = input[i] ⊻ mask[(m - 1) % 4 + 1]
		m += 1
	end
end
