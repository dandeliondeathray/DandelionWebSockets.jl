module DandelionWebSockets

using Compat

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

abstract AbstractWSClient

# This defines the public interface that the user should implement. These are callbacks called when
# events arrive from this WebSocket library.
abstract WebSocketHandler

"Handle a text frame."
on_text(t::WebSocketHandler, ::Compat.UTF8String) = nothing

"Handle a binary frame."
on_binary(t::WebSocketHandler, ::Vector{UInt8}) = nothing

"The WebSocket was closed."
state_closed(t::WebSocketHandler) = nothing

"The WebSocket is about to close."
state_closing(t::WebSocketHandler) = nothing

"The WebSocket is trying to connect."
state_connecting(t::WebSocketHandler) = nothing

"The WebSocket is open and ready to send and receive messages."
state_open(t::WebSocketHandler) = nothing

include("core.jl")
include("taskproxy.jl")
include("glue_interface.jl")
include("network.jl")
include("client_logic.jl")
include("ping.jl")
include("handshake.jl")
include("client.jl")
include("reconnect.jl")
include("mock.jl")

end # module
