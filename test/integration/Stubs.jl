"""
Stubs contains stub implementations of certain parts of the client side of DandelionWebSockets, as
well as simple implementations of the server side of a WebSocket.
"""
module Stubs

using DandelionWebSockets
using DandelionWebSockets: HTTPAdapter, HTTPUpgradeResponse, HeaderList
import DandelionWebSockets: dohandshake
using Base64
using SHA

export ScriptedServer, ScriptedClientHandler, InProcessHandshakeAdapter,
    ShortWait, WaitForOpen, WaitForClose, CloseConnection,
    SendTextFrame, waitforclose

"""
TestAction is an abstract type for different actions for a test client or server to take.
"""
abstract type TestAction end

struct ShortWait <: TestAction end
struct WaitForOpen <: TestAction end
struct WaitForClose <: TestAction end
struct CloseConnection <: TestAction end
struct SendTextFrame <: TestAction
    s::String
end

const ListOfActions = AbstractVector{TestAction}

mutable struct ConnectionStatistics
    received_messages::Int

    ConnectionStatistics() = new(0)
end

function receivedframe(s::ConnectionStatistics, frame::Frame)
    if frame.fin
        s.received_messages += 1
    end
end

"""
ScriptedServer is a stub of a WebSocket server, that follows a pre-defined list of actions.
"""
struct ScriptedServer
    script::ListOfActions
    io::IO
    chanclose::Channel{Nothing}
    statistics::ConnectionStatistics

    # TODO Use a better IO object
    ScriptedServer(script::ListOfActions) = new(script, IOBuffer(), Channel{Nothing}(2), ConnectionStatistics())
end

newconnection(s::ScriptedServer) = s.io
waitforclose(s::ScriptedServer) = take!(s.chanclose)
notifyclosed(s::ScriptedServer) = put!(s.chanclose, nothing)

struct ScriptedClientHandler <: WebSocketHandler
    wsclient::WSClient
    script::ListOfActions
    chanclose::Channel{Nothing}
    statistics::ConnectionStatistics

    ScriptedClientHandler(w::WSClient, script::ListOfActions) = new(w, script, Channel{Nothing}(2), ConnectionStatistics())
end

waitforclose(c::ScriptedClientHandler) = take!(c.chanclose)
notifyclosed(c::ScriptedClientHandler) = put!(c.chanclose, nothing)

"""
InProcessHandshakeAdapter is a stub for an HTTP upgrade request.
"""
struct InProcessHandshakeAdapter <: HTTPAdapter
    server::ScriptedServer
end

function finduniqueheader(headers::HeaderList, name::String)
    vs = [v for (k, v) in headers
          if lowercase(k) == lowercase(name)]

    if length(vs) > 1
        throw(DomainException("Found two occurrences of $name: $vs"))
    end
    if isempty(vs)
        throw(DomainException("Found no occurrences of $name"))
    end

    vs[1]
end

function dohandshake(::HTTPAdapter, uri::String, headers::HeaderList) :: HTTPUpgradeResponse
    io = newclient(server)

    key = finduniqueheader(headers, "Sec-WebSocket-Accept")
    responseheaders = HeaderList[
        "Connection" => "Upgrade",
        "Upgrade" => "websocket",
        "Sec-WebSocket-Accept" => base64encode(sha1(key * "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))]
    HTTPUpgradeResponse(io, 101, responseheaders, b"")
end

"""
Wait for both the server and the client to close their connections.
"""
function waitforclose(server::ScriptedServer, clienthandler::ScriptedClientHandler)
    waitforclose(server)
    waitforclose(clienthandler)
end


end