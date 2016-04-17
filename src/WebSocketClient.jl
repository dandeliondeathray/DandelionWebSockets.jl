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
    handler::WebSocketHandler
    do_handshake::Function
end

stop(c::WSClient) = on_close(c.handler)

end # module
