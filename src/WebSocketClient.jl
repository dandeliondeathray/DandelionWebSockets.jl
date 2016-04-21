module WebSocketClient

export WSClient,
       stop

include("core.jl")
include("network.jl")
include("executor.jl")
include("client_logic.jl")
include("handler.jl")
include("glue.jl")
include("handshake.jl")

immutable WSClient
    writer::ClientWriter
    handler_pump::HandlerPump
    logic_pump::ClientLogicPump
    reader::ServerReader
    logic_chan::Channel{ClientLogicInput}

    function WSClient(uri::Requests.URI, handler::WebSocketHandler; do_handshake=WebSocketClient.do_handshake)
        rng = MersenneTwister()
        handshake_result = do_handshake(rng, uri)

        writer_channel = Channel{Frame}(32)
        writer = start_writer(handshake_result.stream, writer_channel)

        user_channel = Channel{HandlerType}(32)
        handler_pump = start(HandlerPump, handler, user_channel)

        executor = ClientExecutor(writer_channel, user_channel)
        logic = ClientLogic(STATE_OPEN, executor, rng)

        logic_chan = Channel{ClientLogicInput}(32)
        logic_handler = x -> handle(logic, x)
        logic_pump = start_client_logic_pump(logic_handler, logic_chan)

        reader = start_reader(handshake_result.stream, logic_chan)

        c = new(writer, handler_pump, logic_pump, reader, logic_chan)
        on_create(handler, c)
        c
    end
end

stop(c::WSClient) = put!(c.logic_chan, CloseRequest())

end # module
