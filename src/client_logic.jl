# Client logic deals with handling control frames, user requesting to send frames, state.
# The ClientLogic type is defined below entirely synchronously. It takes input via the `handle()`
# function, which is defined for the different input types below. It performs internal logic and
# produces a call to its outbound interface.

export ClientLogicExecutor,
       ClientLogic


#
# These types define the input interface for the client logic.
#
immutable SendTextFrame
	data::UTF8String
	isfinal::Bool
	opcode::Opcode
end

immutable SendBinaryFrame
	data::Array{UInt8, 1}
	isfinal::Bool
	opcode::Opcode
end

immutable ClientPingRequest end

immutable FrameFromServer
	frame::Frame
end

#
# Outbound interface for ClientLogic
#

abstract ClientLogicExecutor

# `send_frame` is called when a frame should be sent to the server.
send_frame(t::ClientLogicExecutor, ::Frame) = error("send_frame undefined for $(t)")

# These are callbacks for state changes to the WebSocket.
state_open(t::ClientLogicExecutor)          = error("state_open undefined for $(t)")
state_closing(t::ClientLogicExecutor)       = error("state_closing undefined for $(t)")
state_closed(t::ClientLogicExecutor)        = error("state_closed undefined for $(t)")

# Callback when a text message is received from the server. Note that it's the entire message, not
# individual frames.
text_received(t::ClientLogicExecutor, ::UTF8String)      = error("text_received undefined for $(t)")

# Callback when a binary message is received from the server. Note that it's the entire message, not
# individual frames.
data_received(t::ClientLogicExecutor, ::Array{UInt8, 1}) = error("data_received undefined for $(t)")

#
# ClientLogic
#

immutable SocketState
	v::Symbol
end

const STATE_CONNECTING = SocketState(:connecting)
const STATE_OPEN       = SocketState(:open)
const STATE_CLOSING    = SocketState(:closing)
const STATE_CLOSED     = SocketState(:closed)

type ClientLogic
	state::SocketState
	executor::ClientLogicExecutor
	rng::AbstractRNG
end

function handle(logic::ClientLogic, req::SendTextFrame)
	if logic.state != STATE_OPEN
		return
	end

	payload = Vector{UInt8}(req.data)
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
		req.isfinal, false, false, false, req.opcode, true, len, extended_len, mask, payload)

	send_frame(logic.executor, frame)
end

handle(logic::ClientLogic, req::SendBinaryFrame)   = nothing
handle(logic::ClientLogic, req::ClientPingRequest) = nothing

function handle(logic::ClientLogic, req::FrameFromServer)
	text_received(logic.executor, utf8(req.frame.payload))
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