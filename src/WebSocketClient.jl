module WebSocketClient

export AbstractWSClient,
       WSClient,
       stop,
       send_text

include("core.jl")
include("network.jl")
include("executor.jl")
include("client_logic.jl")
include("handler.jl")
include("glue.jl")
include("handshake.jl")

abstract AbstractWSClient

immutable WSClient <: AbstractWSClient
    writer::ClientWriter
    handler_pump::HandlerPump
    logic_pump::ClientLogicPump
    reader::ServerReader
    logic_chan::Channel{ClientLogicInput}

    function WSClient(uri::Requests.URI, handler::WebSocketHandler; do_handshake=WebSocketClient.do_handshake)
        rng = MersenneTwister()
        # Requests expect a HTTP/HTTPS scheme, so we convert from the ws/wss to http/https,
        # if necessary.
        new_uri = convert_ws_uri(uri)
        handshake_result = do_handshake(rng, new_uri)

        writer_channel = Channel{Frame}(32)
        writer = start_writer(handshake_result.stream, writer_channel)

        user_channel = Channel{HandlerType}(32)
        handler_pump = start(HandlerPump, handler, user_channel)

        executor = ClientExecutor(writer_channel, user_channel)
        logic = ClientLogic(STATE_OPEN, executor, rng)

        logic_chan = Channel{ClientLogicInput}(32)
        logic_handler = x -> handle(logic, x)
        logic_pump = start_client_logic_pump(logic_handler, logic_chan)

        # TODO: Send state_connecting call?

        reader = start_reader(handshake_result.stream, logic_chan)

        c = new(writer, handler_pump, logic_pump, reader, logic_chan)
        on_create(handler, c)
        c
    end
end

# This method is primarily meant to be used when you want to feed the WebSocket client with another
# channel, rather than going through the normal function calls. For instance, if building a
# throttling layer on top of this you might want to access the logic channel directly.
get_channel(c::WSClient) = c.logic_chan

stop(c::WSClient) = put!(c.logic_chan, CloseRequest())

send_text(c::WSClient, s::UTF8String) = put!(c.logic_chan, SendTextFrame(s, true, OPCODE_TEXT))
# TODO: Support sending binary messages.

end # module
