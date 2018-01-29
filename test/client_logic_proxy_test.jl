using Base.Test
using DandelionWebSockets: SendTextFrame, SendBinaryFrame
using DandelionWebSockets: ClientPingRequest, PongMissed, CloseRequest, SocketClosed
using DandelionWebSockets: FrameFromServer
using DandelionWebSockets.Proxy: ClientLogicProxy
import DandelionWebSockets.Proxy: handle

struct ClientLogicNotification
    datatype::Symbol
    payload::Any
end

struct MockProxiedClientLogic <: AbstractClientLogic
    call_notifications::Channel{ClientLogicNotification}

    MockProxiedClientLogic() = new(Channel{ClientLogicNotification}(0))
end

takenotification!(c::MockProxiedClientLogic) = take!(c.call_notifications)
handle(c::MockProxiedClientLogic, s::SendTextFrame) = put!(c.call_notifications, ClientLogicNotification(:SendTextFrame, s))
handle(c::MockProxiedClientLogic, s::SendBinaryFrame) = put!(c.call_notifications, ClientLogicNotification(:SendBinaryFrame, s))
handle(c::MockProxiedClientLogic, s::ClientPingRequest) = put!(c.call_notifications, ClientLogicNotification(:ClientPingRequest, s))
handle(c::MockProxiedClientLogic, s::PongMissed) = put!(c.call_notifications, ClientLogicNotification(:PongMissed, s))
handle(c::MockProxiedClientLogic, s::CloseRequest) = put!(c.call_notifications, ClientLogicNotification(:CloseRequest, s))
handle(c::MockProxiedClientLogic, s::SocketClosed) = put!(c.call_notifications, ClientLogicNotification(:SocketClosed, s))
handle(c::MockProxiedClientLogic, s::FrameFromServer) = put!(c.call_notifications, ClientLogicNotification(:FrameFromServer, s))

@testset "Client logic proxy   " begin
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
                client_logic = MockProxiedClientLogic()
                proxy = ClientLogicProxy(client_logic)
                handle(proxy, data_in)

                actual_call = takenotification!(client_logic)
                @test actual_call.datatype == expected_datatype
                @test actual_call.payload == data_in
            end
        end

        @testset "Stop a client logic proxy" begin
            client_logic = MockProxiedClientLogic()
            proxy = ClientLogicProxy(client_logic)   

            stopproxy(proxy)

            @test isopen(proxy.channel) == false
        end
    end
end