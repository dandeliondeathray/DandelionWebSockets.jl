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
    handler::WebSocketHandler # TODO: Remove when closing has been implemented

    function WSClient(handler::WebSocketHandler, do_handshake::Function)
        handshake_result = do_handshake()

        writer_channel = Channel{Frame}(32)
        writer = start_writer(handshake_result.stream, writer_channel)

        user_channel = Channel{HandlerType}(32)
        handler_pump = start(HandlerPump, handler, user_channel)

        executor = ClientExecutor(writer_channel, user_channel)
        logic = ClientLogic(STATE_CONNECTING, executor, MersenneTwister())

        logic_chan = Channel{ClientLogicInput}(32)
        logic_handler = x -> handle(logic, x)
        logic_pump = start_client_logic_pump(logic_handler, logic_chan)

        reader = start_reader(handshake_result.stream, logic_chan)

        new(writer, handler_pump, logic_pump, reader, handler)
    end
end

stop(c::WSClient) = on_close(c.handler)

end # module
