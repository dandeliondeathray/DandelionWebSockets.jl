module WebSocketClient

export AbstractWSClient,
       WSClient,
       stop,
       send_text

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

include("core.jl")
include("taskproxy.jl")
include("glue_interface.jl")
include("network.jl")
include("client_logic.jl")
include("handler.jl")
include("handshake.jl")

# This defines the public interface that the user should implement. These are callbacks called when
# events arrive from this WebSocket library.
abstract WebSocketHandler

on_text(t::WebSocketHandler, ::UTF8String) = error("on_text not implemented for $(typeof(t))")
on_binary(t::WebSocketHandler, ::Vector{UInt8}) = error("on_binary not implemented for $(typeof(t))")
on_create(t::WebSocketHandler) = error("on_create not implemented for $(typeof(t))")
state_closed(t::WebSocketHandler) = error("state_closed not implemented for $(typeof(t))")
state_closing(t::WebSocketHandler) = error("state_closing not implemented for $(typeof(t))")
state_connecting(t::WebSocketHandler) = error("state_connecting not implemented for $(typeof(t))")
state_open(t::WebSocketHandler) = error("state_open not implemented for $(typeof(t))")

include("glue.jl")

#abstract AbstractWSClient
#
#immutable WSClient <: AbstractWSClient
#    writer::ClientWriter
#    handler_pump::HandlerPump
#    logic_pump::ClientLogicPump
#    reader::ServerReader
#    logic_chan::Channel{ClientLogicInput}
#
#    function WSClient(uri::Requests.URI, handler::WebSocketHandler; do_handshake=WebSocketClient.do_handshake)
#        rng = MersenneTwister()
#        # Requests expect a HTTP/HTTPS scheme, so we convert from the ws/wss to http/https,
#        # if necessary.
#        new_uri = convert_ws_uri(uri)
#        handshake_result = do_handshake(rng, new_uri)
#
#        writer_channel = Channel{Frame}(32)
#        writer = start_writer(handshake_result.stream, writer_channel)
#
#        user_channel = Channel{HandlerType}(32)
#        handler_pump = start(HandlerPump, handler, user_channel)
#
#        executor = ClientExecutor(writer_channel, user_channel)
#        logic = ClientLogic(STATE_OPEN, executor, rng)
#
#        logic_chan = Channel{ClientLogicInput}(32)
#        logic_handler = x -> handle(logic, x)
#        logic_pump = start_client_logic_pump(logic_handler, logic_chan)
#
#        # TODO: Send state_connecting call?
#
#        reader = start_reader(handshake_result.stream, logic_chan)
#
#        c = new(writer, handler_pump, logic_pump, reader, logic_chan)
#        on_create(handler, c)
#        c
#    end
#end

# This method is primarily meant to be used when you want to feed the WebSocket client with another
# channel, rather than going through the normal function calls. For instance, if building a
# throttling layer on top of this you might want to access the logic channel directly.
#get_channel(c::WSClient) = c.logic_chan
#
#stop(c::WSClient) = put!(c.logic_chan, CloseRequest())
#
#send_text(c::WSClient, s::UTF8String) = put!(c.logic_chan, SendTextFrame(s, true, OPCODE_TEXT))
# TODO: Support sending binary messages.

end # module
