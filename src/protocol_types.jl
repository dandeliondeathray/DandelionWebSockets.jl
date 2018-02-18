#
# These types define the different connection states for the protocol.
#

# TODO: REname to ConnectionState, because the socket is the TCP Socket
"Enum value for the different states a WebSocket can be in."
struct SocketState
	v::Symbol
end

const STATE_CONNECTING     = SocketState(:connecting)
const STATE_OPEN           = SocketState(:open)
const STATE_CLOSING        = SocketState(:closing)
const STATE_CLOSING_SOCKET = SocketState(:closing_socket)
const STATE_CLOSED         = SocketState(:closed)

#
# These types define the input interface for the client logic.
#

"Abstract type for all commands sent to `ClientProtocol`.

These commands are sent as arguments to the different `handle` functions on `ClientProtocol`. Each
command represents an action on a WebSocket, such as sending a text frame, ping request, or closing
the connection."
abstract type ClientProtocolInput end

"Send a text frame, sent to `ClientProtocol`."
struct SendTextFrame <: ClientProtocolInput
	data::Vector{UInt8}
	# True if this is the final frame in the text message.
	isfinal::Bool
	# What WebSocket opcode should be used.
	opcode::Opcode

	SendTextFrame(data::Vector{UInt8}, isfinal::Bool, opcode::Opcode) = new(data, isfinal, opcode)
	SendTextFrame(data::String, isfinal::Bool, opcode::Opcode) = new(Vector{UInt8}(data), isfinal, opcode)
end

"Send a binary frame, sent to `ClientProtocol`."
struct SendBinaryFrame <: ClientProtocolInput
	data::Array{UInt8, 1}
	# True if this is the final frame in the text message.
	isfinal::Bool
	# What WebSocket opcode should be used.
	opcode::Opcode
end

"Send a ping request to the server."
struct ClientPingRequest  <: ClientProtocolInput end

"A frame was received from the server."
struct FrameFromServer <: ClientProtocolInput
	frame::Frame
end

"A request to close the WebSocket."
struct CloseRequest <: ClientProtocolInput end

"Used when the underlying network socket was closed."
struct SocketClosed <: ClientProtocolInput end

"A pong reply was expected, but never received."
struct PongMissed <: ClientProtocolInput end

"No Close frame response was received by the client after a reasonable time"
struct AbnormalNoCloseResponseReceived <: ClientProtocolInput end