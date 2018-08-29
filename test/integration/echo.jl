"""
The `echo` integration test runs a fake WebSocket server that echoes all frames sent to it.

It runs in process, without any actual network sockets. It does this by faking the connection using
a channel instead of an actual socket. The vast majority of the code can still be executed, as is.
Only a small portion of code is specific to the actual network.
"""
using DandelionWebSockets: HTTPHandshake
using Random


"""
EchoServerHandler defines the behaviour of the fake in-process server that echoes anything sent to
it.
"""
struct EchoServerHandler <: WebSocketHandler
    connection::AbstractWSClient
end

on_text(e::EchoServerHandler, text::String) = send_text(e.connection, text)
on_binary(e::EchoServerHandler, data::AbstractVector{UInt8}) = send_binary(e.connection, data)
state_closed(e::EchoServerHandler) = nothing
state_closing(e::EchoServerHandler) = nothing
state_connecting(e::EchoServerHandler) = nothing
state_open(e::EchoServerHandler) = nothing

"""
EchoClientHandler defines the behaviour of the test, which is to send a bunch of messages to the
server and verify that we get an echo back for all of them.
"""
mutable struct EchoClientHandler
    client::WSClient
end

on_text(e::EchoClientHandler, text::String) = verifyecho(e, text)
on_binary(e::EchoClientHandler, data::AbstractVector{UInt8}) = verifyecho(e, data)
state_closed(e::EchoClientHandler) = nothing
state_closing(e::EchoClientHandler) = nothing
state_connecting(e::EchoClientHandler) = nothing
state_open(e::EchoClientHandler) = nothing

function verifyecho(e::EchoClientHandler, text::String)
    expected = "$(e.counter)"
    if expected == text
        if e.counter >= e.limit
            success(e)
        else
            e.counter += 1
            sendprobe(e, "$(e.counter)")
        end
    else
        println("ERROR: Expected '$expected', but got '$text'")
        failure(e)
    end
end

function sendprobe(e::EchoClientHandler, text::String)
    sendtext(e.client, text)
end

success(e::EchoClientHandler) = println("SUCCESS!")
failure(e::EchoClientHandler) = println("FAILURE!")

server = InProcessServer(EchoServerHandler)
# This replaces the `HTTPjlAdapter` type, which uses the `HTTP.jl` package to make an actual HTTP
# connection. This adapter instead asks the server for a channel, and uses that for returning a
# correct HTTP upgrade reply.
handshakeadapter = InProcessHandshakeAdapter(server)

client = WSClient(; handshake=HTTPHandshake(RandomDevice(), handshakeadapter))
echoclient = EchoClientHandler(client)

wsconnect(client, "ws://the/uri/does/not/matter/here", echoclient)

