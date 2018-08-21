using DandelionWebSockets
using DandelionWebSockets: STATE_OPEN, STATE_CONNECTING, STATE_CLOSING, STATE_CLOSED
using DandelionWebSockets: SocketState, AbstractPonger, SendTextFrame, FrameFromServer
using DandelionWebSockets: handle
import DandelionWebSockets: write
import DandelionWebSockets: on_text, on_binary
import DandelionWebSockets: state_connecting, state_open, state_closing, state_closed
using Test

include("stubs.jl")
include("test_factories.jl")
include("issues_test.jl")
include("client_protocol_from_server_test.jl")
include("client_protocol_from_client_test.jl")
include("client_protocol_connection_test.jl")
include("masking_test.jl")
include("core_test.jl")
include("handshake_short_test.jl")
include("handshake_logic_test.jl")
include("security_considerations_test.jl")
include("data_frames_test.jl")
include("frame_sender_test.jl")
include("frame_writer_test.jl")
include("closing_behaviour_test.jl")
include("network_small_test.jl")