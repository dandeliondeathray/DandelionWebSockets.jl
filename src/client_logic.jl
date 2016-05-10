# Client logic deals with handling control frames, user requesting to send frames, state.
# The ClientLogic type is defined below entirely synchronously. It takes input via the `handle()`
# function, which is defined for the different input types below. It performs internal logic and
# produces a call to its outbound interface.

export ClientLogic

#
# These types define the input interface for the client logic.
#

abstract ClientLogicInput

immutable SendTextFrame <: ClientLogicInput
	data::UTF8String
	isfinal::Bool
	opcode::Opcode
end

immutable SendBinaryFrame <: ClientLogicInput
	data::Array{UInt8, 1}
	isfinal::Bool
	opcode::Opcode
end

immutable ClientPingRequest  <: ClientLogicInput end

immutable FrameFromServer <: ClientLogicInput
	frame::Frame
end

immutable CloseRequest <: ClientLogicInput end
immutable SocketClosed <: ClientLogicInput end

#
# ClientLogic
#

immutable SocketState
	v::Symbol
end

const STATE_CONNECTING     = SocketState(:connecting)
const STATE_OPEN           = SocketState(:open)
const STATE_CLOSING        = SocketState(:closing)
const STATE_CLOSING_SOCKET = SocketState(:closing_socket)
const STATE_CLOSED         = SocketState(:closed)

type ClientLogic
	state::SocketState
	executor::AbstractClientExecutor
	rng::AbstractRNG
	buffer::Vector{UInt8}
	buffered_type::Opcode
end

ClientLogic(state::SocketState,
	        executor::AbstractClientExecutor,
	        rng::AbstractRNG) = ClientLogic(state, executor, rng, Vector{UInt8}(), OPCODE_TEXT)

function send(logic::ClientLogic, isfinal::Bool, opcode::Opcode, payload::Vector{UInt8})
	mask    = rand(logic.rng, UInt8, 4)
	masking!(payload, mask)
	len::UInt64  = length(payload)
	extended_len = 0

	if 128 <= len <= 65536
		extended_len = len
		len = 126
	elseif 65536 + 1 <= len
		extended_len = len
		len = 127
	end

	frame = Frame(
		isfinal, false, false, false, opcode, true, len, extended_len, mask, payload)

	send_frame(logic.executor, frame)
end

function handle(logic::ClientLogic, req::SendTextFrame)
	if logic.state != STATE_OPEN
		return
	end

	payload = Vector{UInt8}(req.data)
	send(logic, req.isfinal, req.opcode, payload)
end

handle(logic::ClientLogic, req::SendBinaryFrame)   = nothing
handle(logic::ClientLogic, req::ClientPingRequest) = nothing

function handle(logic::ClientLogic, req::CloseRequest)
	logic.state = STATE_CLOSING
	mask = rand(logic.rng, UInt8, 4)
	frame = Frame(true, false, false, false, OPCODE_CLOSE, true, 0, 0,
		mask, b"")
	send_frame(logic.executor, frame)
	state_closing(logic.executor)
end

function handle(logic::ClientLogic, ::SocketClosed)
	logic.state = STATE_CLOSED
	state_closed(logic.executor)
end

function handle(logic::ClientLogic, req::FrameFromServer)
	if req.frame.opcode == OPCODE_CLOSE
		handle_close(logic, req.frame)
	elseif req.frame.opcode == OPCODE_PING
		handle_ping(logic, req.frame.payload)
	elseif req.frame.opcode == OPCODE_TEXT
		handle_text(logic, req.frame)
	elseif req.frame.opcode == OPCODE_BINARY
		handle_binary(logic, req.frame)
	elseif req.frame.opcode == OPCODE_CONTINUATION
		handle_continuation(logic, req.frame)
	end
end

#
# Internal handle functions
#

function handle_close(logic::ClientLogic, frame::Frame)
	# If the server initiates a closing handshake when we're in open, we should reply with a close
	# frame. If the client initiated the closing handshake then we'll be in STATE_CLOSING when the
	# reply comes, and we shouldn't send another close frame.
	send_close_reply = logic.state == STATE_OPEN
	logic.state = STATE_CLOSING_SOCKET
	if send_close_reply
		mask = rand(logic.rng, UInt8, 4)
		frame = Frame(true, false, false, false, OPCODE_CLOSE, true, frame.len, frame.extended_len,
			mask, frame.payload)
		send_frame(logic.executor, frame)
		state_closing(logic.executor)
	end
end

function handle_ping(logic::ClientLogic, payload::Vector{UInt8})
	send(logic, true, OPCODE_PONG, payload)
end

function handle_text(logic::ClientLogic, frame::Frame)
	if frame.fin
		on_text(logic.executor, utf8(frame.payload))
	else
		start_buffer(logic, frame.payload, OPCODE_TEXT)
	end
end

function handle_binary(logic::ClientLogic, frame::Frame)
	if frame.fin
		on_binary(logic.executor, frame.payload)
	else
		start_buffer(logic, frame.payload, OPCODE_BINARY)
	end
end

function handle_continuation(logic::ClientLogic, frame::Frame)
	buffer(logic, frame.payload)
	if frame.fin
		if logic.buffered_type == OPCODE_TEXT
			on_text(logic.executor, utf8(logic.buffer))
		elseif logic.buffered_type == OPCODE_BINARY
			on_binary(logic.executor, logic.buffer)
			logic.buffer = Vector{UInt8}()
		end
	end
end

function start_buffer(logic::ClientLogic, payload::Vector{UInt8}, opcode::Opcode)
	logic.buffered_type = opcode
	logic.buffer = copy(payload)
end

function buffer(logic::ClientLogic, payload::Vector{UInt8})
	append!(logic.buffer, payload)
end

#
# Utilities
#

function masking!(input::Vector{UInt8}, mask::Vector{UInt8})
	m = 1
	for i in 1:length(input)
		input[i] = input[i] $ mask[(m - 1) % 4 + 1]
		m += 1
	end
end