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

abstract AbstractWSClient

# This defines the public interface that the user should implement. These are callbacks called when
# events arrive from this WebSocket library.
abstract WebSocketHandler

on_text(t::WebSocketHandler, ::UTF8String) = nothing
on_binary(t::WebSocketHandler, ::Vector{UInt8}) = nothing
state_closed(t::WebSocketHandler) = nothing
state_closing(t::WebSocketHandler) = nothing
state_connecting(t::WebSocketHandler) = nothing
state_open(t::WebSocketHandler) = nothing

include("core.jl")
include("taskproxy.jl")
include("glue_interface.jl")
include("network.jl")
include("client_logic.jl")
include("handshake.jl")
include("glue.jl")
include("client.jl")
include("reconnect.jl")
include("mock.jl")

end # module
