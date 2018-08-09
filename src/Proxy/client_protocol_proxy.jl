using DandelionWebSockets: AbstractClientProtocol, SendTextFrame, SendBinaryFrame
using DandelionWebSockets: ClientPingRequest, PongMissed, CloseRequest, SocketClosed
using DandelionWebSockets: FrameFromServer
import DandelionWebSockets: handle

export ClientProtocolProxy

struct ClientProtocolProxy <: AbstractClientProtocol
    channel::Channel{Any}
    clientlogic::AbstractClientProtocol

    function ClientProtocolProxy(clientlogic::AbstractClientProtocol)
        proxy = new(Channel{Any}(Inf), clientlogic)
        @async run_clientlogicproxy(proxy)
        proxy
    end
end

function run_clientlogicproxy(c::ClientProtocolProxy)
    for p in c.channel
        handle(c.clientlogic, p)
    end
end

handle(proxy::ClientProtocolProxy, s::SendTextFrame) = put!(proxy.channel, s)
handle(proxy::ClientProtocolProxy, s::SendBinaryFrame) = put!(proxy.channel, s)
handle(proxy::ClientProtocolProxy, s::ClientPingRequest) = put!(proxy.channel, s)
handle(proxy::ClientProtocolProxy, s::PongMissed) = put!(proxy.channel, s)
handle(proxy::ClientProtocolProxy, s::CloseRequest) = put!(proxy.channel, s)
handle(proxy::ClientProtocolProxy, s::SocketClosed) = put!(proxy.channel, s)
handle(proxy::ClientProtocolProxy, s::FrameFromServer) = put!(proxy.channel, s)

stopproxy(proxy::ClientProtocolProxy) = close(proxy.channel)