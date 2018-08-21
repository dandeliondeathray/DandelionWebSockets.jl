__precompile__(true)

module DandelionWebSockets

export AbstractWSClient,
       WSClient,
       stop,
       send_text,
       send_binary

export WebSocketHandler,
       on_text,
       on_binary,
       state_closed,
       state_closing,
       state_connecting,
       state_open,
       wsconnect
export AbstractClientProtocol

abstract type AbstractWSClient end
abstract type AbstractClientProtocol end
abstract type AbstractPinger end
abstract type AbstractPonger end
abstract type ClosingBehaviour end
abstract type AbstractFrameWriter end

# This defines the public interface that the user should implement. These are callbacks called when
# events arrive from this WebSocket library.
abstract type WebSocketHandler end

"Handle a text frame."
on_text(t::WebSocketHandler, ::String) = nothing

"Handle a binary frame."
on_binary(t::WebSocketHandler, ::AbstractVector{UInt8}) = nothing

"The WebSocket was closed."
state_closed(t::WebSocketHandler) = nothing

"The WebSocket is about to close."
state_closing(t::WebSocketHandler) = nothing

"The WebSocket is trying to connect."
state_connecting(t::WebSocketHandler) = nothing

"The WebSocket is open and ready to send and receive messages."
state_open(t::WebSocketHandler) = nothing

include("core.jl")
include("protocol_types.jl")
include("network.jl")
include("closing_behaviour.jl")
include("frame_writer.jl")
include("client_protocol.jl")
include("ping.jl")
include("handshake.jl")
include("handshake_logic.jl")
include("Proxy/Proxy.jl")
include("frame_sender.jl")
include("client.jl")
include("reconnect.jl")
include("mock.jl")

end # module
