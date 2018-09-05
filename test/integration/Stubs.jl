"""
Stubs contains stub implementations of certain parts of the client side of DandelionWebSockets, as
well as simple implementations of the server side of a WebSocket.
"""
module Stubs

using DandelionWebSockets
using DandelionWebSockets:
    HTTPAdapter, HTTPUpgradeResponse, HeaderList, Frame, OPCODE_TEXT, Opcode
import DandelionWebSockets: dohandshake, tcpnodelay, on_text, on_binary, send_text, send_binary,
                            state_connecting, state_open, state_closing, state_closed
import Base: read, write, eof, close

using Base64
using SHA

export ScriptedServer, ScriptedClientHandler, InProcessHandshakeAdapter,
    ShortWait, WaitForOpen, WaitForClose, CloseConnection,
    SendTextFrame, waitforscriptdone, InProcessIO, InProcessIOPair

const DataChannel = Channel{Union{Vector{UInt8}, Nothing}}

"""
InProcessIO is a fake network socket that uses `Channel`s for asynchronous communication.
"""
mutable struct InProcessIO <: IO
    readbuffer::IOBuffer
    writechan::DataChannel
    readchan::DataChannel
    iseof::Threads.Atomic{Bool}

    InProcessIO(writechan::DataChannel, readchan::DataChannel) =
        new(IOBuffer(), writechan, readchan, Threads.Atomic{Bool}(false))
end

function eof(io::InProcessIO)
    iseofalready = io.iseof[]
    if iseofalready
        return true
    end

    # Read a byte and see if it makes us EOF
    try
        mark(io.readbuffer)
        _fetch(io)
        reset(io.readbuffer)
    catch ex
        if typeof(ex) != EOFError
            rethrow()
        end
    end
    io.iseof[]
end

function _fetch(io::InProcessIO)
    newdata = take!(io.readchan)
    if newdata == nothing
        Threads.atomic_or!(io.iseof, true)
        throw(EOFError())
    else
        write(io.readbuffer, newdata)
    end
end

function close(io::InProcessIO)
    put!(io.writechan, nothing)
end

function _write(io::InProcessIO, v::T) where T
    b = IOBuffer()
    write(b, v)
    data = take!(b)
    put!(io.writechan, data)
    yield()
end
write(io::InProcessIO, v::UInt8) = _write(io, v)
function write(io::InProcessIO, cs::Base.CodeUnits{UInt8, String})
    put!(io.writechan, Vector{UInt8}(cs))
    yield()
end
function _read(io::InProcessIO, ::Type{T}) where T
    m = mark(io.readbuffer)
    while true
        try
            return read(io.readbuffer, T)
        catch ex
            if typeof(ex) != EOFError
                rethrow()
            end
        end
        try
            _fetch(io)
            seek(io.readbuffer, m)
        catch ex
            rethrow()
        end
    end
end
read(io::InProcessIO, v::Type{UInt8}) = _read(io, v)
read(io::InProcessIO, v::Type{UInt16}) = _read(io, v)
read(io::InProcessIO, v::Type{UInt64}) = _read(io, v)
function read(io::InProcessIO, n::Integer)
    m = mark(io.readbuffer)
    while true
        if io.readbuffer.size - io.readbuffer.ptr + 1 >= n
            return read(io.readbuffer, n)
        else
            _fetch(io)
            seek(io.readbuffer, m)
        end
    end
end

"""
InProcessIOPair creates two endpoints, one for a client and one for a server. What is written on
one endpoint can be read on the other.
"""
struct InProcessIOPair
    endpoint1::InProcessIO
    endpoint2::InProcessIO

    function InProcessIOPair()
        c1 = DataChannel(Inf)
        c2 = DataChannel(Inf)
        new(InProcessIO(c1, c2), InProcessIO(c2, c1))
    end
end


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
    texts_received::Int
    binaries_received::Int

    ConnectionStatistics() = new(0, 0)
end

receivedtext(s::ConnectionStatistics) = s.texts_received += 1
receivedbinary(s::ConnectionStatistics) = s.binaries_received += 1

"""
ScriptedServer is a stub of a WebSocket server, that follows a pre-defined list of actions.
"""
struct ScriptedServer
    script::ListOfActions
    io::IO
    chanclose::Channel{Nothing}
    chanopen::Channel{Nothing}
    chanscriptdone::Channel{Nothing}
    statistics::ConnectionStatistics

    # TODO Use a better IO object
    function ScriptedServer(script::ListOfActions)
        this = new(script, IOBuffer(), Channel{Nothing}(1), Channel{Nothing}(1), Channel{Nothing}(1), ConnectionStatistics())
        @async runscript(this)
        this
    end
end

function newconnection(s::ScriptedServer)
    notifyopen(s)
    s.io
end
waitforclose(s::ScriptedServer) = take!(s.chanclose)
notifyclosed(s::ScriptedServer) = put!(s.chanclose, nothing)
notifyopen(s::ScriptedServer) = put!(s.chanopen, nothing)
waitforopen(s::ScriptedServer) = take!(s.chanopen)
notifyscriptdone(s::ScriptedServer) = put!(s.chanscriptdone, nothing)
waitforscriptdone(s::ScriptedServer) = take!(s.chanscriptdone)
write(s::ScriptedServer, frame::Frame) = write(s.io, frame)

createserverframe(opcode::Opcode, data::AbstractVector{UInt8}) = 
    Frame(true, opcode, false, length(data), 0, b"", data)
createtextframe(s::String) = createserverframe(OPCODE_TEXT, codeunits(s))

takeaction(s::ScriptedServer, ::WaitForOpen) = waitforopen(s)
takeaction(::ScriptedServer, ::ShortWait) = sleep(0.5)
takeaction(s::ScriptedServer, send::SendTextFrame) = write(s, createtextframe(send.s))
takeaction(s::ScriptedServer, ::WaitForClose) = waitforclose(s)
takeaction(s::ScriptedServer, ::CloseConnection) = close(s.io)

function runscript(s::ScriptedServer)
    for action in s.script
        println("Server: $(action)")
        try
            takeaction(s, action)
        catch ex
            println("Server: Action $(action) threw an exception: $ex")
            break
        end
        println("Server: $(action) DONE")
    end
    notifyscriptdone(s)
end

# Override this to make tcpnodelay a no-op for our fake socket
tcpnodelay(::IOBuffer) = nothing

"""
ScriptedClientHandler is a WebSocket client implementation that follows a fixed script.
"""
struct ScriptedClientHandler <: WebSocketHandler
    wsclient::WSClient
    script::ListOfActions
    chanclose::Channel{Nothing}
    chanopen::Channel{Nothing}
    chanscriptdone::Channel{Nothing}
    statistics::ConnectionStatistics

    function ScriptedClientHandler(w::WSClient, script::ListOfActions)
        this = new(w, script, Channel{Nothing}(1), Channel{Nothing}(1), Channel{Nothing}(1), ConnectionStatistics())
        @async runscript(this)
        this
    end
end

waitforclose(c::ScriptedClientHandler) = take!(c.chanclose)
notifyclosed(c::ScriptedClientHandler) = put!(c.chanclose, nothing)
notifyopen(c::ScriptedClientHandler) = put!(c.chanopen, nothing)
waitforopen(c::ScriptedClientHandler) = take!(c.chanopen)
notifyscriptdone(c::ScriptedClientHandler) = put!(c.chanscriptdone, nothing)
waitforscriptdone(c::ScriptedClientHandler) = take!(c.chanscriptdone)

takeaction(c::ScriptedClientHandler, ::WaitForOpen) = waitforopen(c)
takeaction(::ScriptedClientHandler, ::ShortWait) = sleep(0.5)
takeaction(c::ScriptedClientHandler, send::SendTextFrame) = send_text(c.wsclient, send.s)
takeaction(c::ScriptedClientHandler, ::WaitForClose) = waitforclose(c)
takeaction(c::ScriptedClientHandler, ::CloseConnection) = stop(c.wsclient)

function runscript(c::ScriptedClientHandler)
    for action in c.script
        println("Client: $(action)")
        try
            takeaction(c, action)
        catch ex
            println("Client: Action $(action) threw an exception: $ex")
            break
        end
        println("Client: $(action) DONE")
    end
    notifyscriptdone(c)
end

on_text(t::ScriptedClientHandler, ::String) = receivedtext(t.statistics)
on_binary(t::ScriptedClientHandler, ::AbstractVector{UInt8}) = receivedbinary(t.statistics)
state_closed(t::ScriptedClientHandler) = notifyclosed(t)
state_closing(t::ScriptedClientHandler) = nothing
state_connecting(t::ScriptedClientHandler) = nothing
state_open(t::ScriptedClientHandler) = notifyopen(t)


"""
InProcessHandshakeAdapter is a stub for an HTTP upgrade request.
"""
struct InProcessHandshakeAdapter <: HTTPAdapter
    server::ScriptedServer
end

function finduniqueheader(headers::HeaderList, name::String) :: String
    vs = [v for (k, v) in headers
          if lowercase(k) == lowercase(name)]

    if length(vs) > 1
        throw(DomainError("Found two occurrences of $name: $vs"))
    end
    if isempty(vs)
        throw(DomainError("Found no occurrences of $name"))
    end

    vs[1]
end

function dohandshake(adapter::InProcessHandshakeAdapter, uri::String, headers::HeaderList) :: HTTPUpgradeResponse
    io = newconnection(adapter.server)

    key = finduniqueheader(headers, "Sec-WebSocket-Key")
    responseheaders = [
        "Connection" => "Upgrade",
        "Upgrade" => "websocket",
        "Sec-WebSocket-Accept" => base64encode(sha1(key * "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))]
    HTTPUpgradeResponse(io, 101, responseheaders, b"")
end

"""
Wait for both the server and the client to close their connections.
"""
function waitforscriptdone(server::ScriptedServer, clienthandler::ScriptedClientHandler)
    waitforscriptdone(server)
    waitforscriptdone(clienthandler)
end


end