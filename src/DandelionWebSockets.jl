module DandelionWebSockets

export AbstractWSClient,
       WSClient,
       stop,
       send_text,
       send_binary

export WebSocketHandler,
       on_text,
       on_binary,
       on_create,
       state_closed,
       state_closing,
       state_connecting,
       state_open

# TODO: Move all of the public interface here, and move away anything that isn't a public
#       interface.

abstract AbstractWSClient
# This defines the public interface that the user should implement. These are callbacks called when
# events arrive from this WebSocket library.
abstract WebSocketHandler

on_text(t::WebSocketHandler, ::UTF8String) = nothing
on_binary(t::WebSocketHandler, ::Vector{UInt8}) = nothing
on_create(t::WebSocketHandler) = nothing
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
include("client.jl")


include("glue.jl")

# This method is primarily meant to be used when you want to feed the WebSocket client with another
# channel, rather than going through the normal function calls. For instance, if building a
# throttling layer on top of this you might want to access the logic channel directly.
get_channel(c::WSClient) = c.logic_proxy.chan

stop(c::WSClient) = handle(c.logic_proxy, CloseRequest())

send_text(c::WSClient, s::UTF8String) = handle(c.logic_proxy, SendTextFrame(s, true, OPCODE_TEXT))
send_binary(c::WSClient, data::Vector{UInt8}) =
    handle(c.logic_proxy, SendBinaryFrame(data, true, OPCODE_BINARY))


end # module
