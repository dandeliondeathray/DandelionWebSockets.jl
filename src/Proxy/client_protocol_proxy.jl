using DandelionWebSockets: AbstractClientProtocol, SendTextFrame, SendBinaryFrame
using DandelionWebSockets: ClientPingRequest, PongMissed, CloseRequest, SocketClosed
using DandelionWebSockets: FrameFromServer
import DandelionWebSockets: handle

export ClientLogicProxy

struct ClientLogicProxy <: AbstractClientProtocol
    channel::Channel{Any}
    clientlogic::AbstractClientProtocol

    function ClientLogicProxy(clientlogic::AbstractClientProtocol)
        proxy = new(Channel{Any}(Inf), clientlogic)
        @schedule run_clientlogicproxy(proxy)
        proxy
    end
end

function run_clientlogicproxy(c::ClientLogicProxy)
    for p in c.channel
        handle(c.clientlogic, p)
    end
end

handle(proxy::ClientLogicProxy, s::SendTextFrame) = put!(proxy.channel, s)
handle(proxy::ClientLogicProxy, s::SendBinaryFrame) = put!(proxy.channel, s)
handle(proxy::ClientLogicProxy, s::ClientPingRequest) = put!(proxy.channel, s)
handle(proxy::ClientLogicProxy, s::PongMissed) = put!(proxy.channel, s)
handle(proxy::ClientLogicProxy, s::CloseRequest) = put!(proxy.channel, s)
handle(proxy::ClientLogicProxy, s::SocketClosed) = put!(proxy.channel, s)
handle(proxy::ClientLogicProxy, s::FrameFromServer) = put!(proxy.channel, s)

stopproxy(proxy::ClientLogicProxy) = close(proxy.channel)