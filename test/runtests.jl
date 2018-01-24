using DandelionWebSockets
using FactCheck

include("mock_test.jl")
include("utilities.jl")

include("core_test.jl")
# include("network_test.jl")
include("ping_test.jl")
include("taskproxy_test.jl")
include("glue_test.jl")
include("handshake_test.jl")
include("ws_client_test.jl")
include("reconnect_test.jl")
include("integration_test.jl")

include("runshorttests.jl")
