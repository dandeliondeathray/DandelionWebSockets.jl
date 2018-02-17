using Base.Test
using DandelionWebSockets: SendTextFrame, SendBinaryFrame
using DandelionWebSockets: ClientPingRequest, PongMissed, CloseRequest, SocketClosed
using DandelionWebSockets: FrameFromServer
using DandelionWebSockets.Proxy: ClientProtocolProxy
import DandelionWebSockets.Proxy: handle

struct ClientProtocolNotification
    datatype::Symbol
    payload::Any
end

struct MockProxiedClientProtocol <: AbstractClientProtocol
    call_notifications::Channel{ClientProtocolNotification}

    MockProxiedClientProtocol() = new(Channel{ClientProtocolNotification}(0))
end

takenotification!(c::MockProxiedClientProtocol) = take!(c.call_notifications)
handle(c::MockProxiedClientProtocol, s::SendTextFrame) = put!(c.call_notifications, ClientProtocolNotification(:SendTextFrame, s))
handle(c::MockProxiedClientProtocol, s::SendBinaryFrame) = put!(c.call_notifications, ClientProtocolNotification(:SendBinaryFrame, s))
handle(c::MockProxiedClientProtocol, s::ClientPingRequest) = put!(c.call_notifications, ClientProtocolNotification(:ClientPingRequest, s))
handle(c::MockProxiedClientProtocol, s::PongMissed) = put!(c.call_notifications, ClientProtocolNotification(:PongMissed, s))
handle(c::MockProxiedClientProtocol, s::CloseRequest) = put!(c.call_notifications, ClientProtocolNotification(:CloseRequest, s))
handle(c::MockProxiedClientProtocol, s::SocketClosed) = put!(c.call_notifications, ClientProtocolNotification(:SocketClosed, s))
handle(c::MockProxiedClientProtocol, s::FrameFromServer) = put!(c.call_notifications, ClientProtocolNotification(:FrameFromServer, s))

@testset "Client logic proxy     " begin
    @testset "Callbacks are done one a separate task" begin
        tests = [
            (SendTextFrame("some data", true, OPCODE_TEXT), :SendTextFrame),
            (SendBinaryFrame(b"some data", true, OPCODE_BINARY), :SendBinaryFrame),
            (ClientPingRequest(), :ClientPingRequest),
            (PongMissed(), :PongMissed),
            (CloseRequest(), :CloseRequest),
            (SocketClosed(), :SocketClosed),
            (FrameFromServer(Frame(true,0, 0, 0, OPCODE_TEXT, false, 1, 0, Vector{UInt8}(), b"1")), :FrameFromServer),
        ]

        for test in tests
            data_in = test[1]
            expected_datatype = test[2]

            @testset "Client logic proxy handles a $expected_datatype" begin
                client_logic = MockProxiedClientProtocol()
                proxy = ClientProtocolProxy(client_logic)
                handle(proxy, data_in)

                actual_call = takenotification!(client_logic)
                @test actual_call.datatype == expected_datatype
                @test actual_call.payload == data_in
            end
        end

        @testset "Stop a client logic proxy" begin
            client_logic = MockProxiedClientProtocol()
            proxy = ClientProtocolProxy(client_logic)

            stopproxy(proxy)

            @test isopen(proxy.channel) == false
        end
    end
end