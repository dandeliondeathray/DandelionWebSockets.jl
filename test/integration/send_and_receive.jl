# "Send and receive" is an integration test that verifies that the client can send and receive
# messages.
# 
# Five messages are sent from the client to the server, and five messages are sent from the server
# to the client.

include("Stubs.jl")

using DandelionWebSockets
using DandelionWebSockets: HTTPHandshake
using .Stubs
using Test
using Random

# These are the actions that the server will take.
serverscript = [
    WaitForOpen(),
    SendTextFrame("1234"),
    ShortWait(),
    SendTextFrame("2345"),
    ShortWait(),
    SendTextFrame("3456"),
    ShortWait(),
    SendTextFrame("4567"),
    ShortWait(),
    SendTextFrame("5678"),
    WaitForClose()
]

clientscript = [
    WaitForOpen(),
    SendTextFrame("abcd"),
    ShortWait(),
    SendTextFrame("bcde"),
    ShortWait(),
    SendTextFrame("cdef"),
    ShortWait(),
    SendTextFrame("defg"),
    ShortWait(),
    SendTextFrame("efgh"),
    ShortWait(),
    CloseConnection()
]

# Create server, and the handshake adapter that creates the connection when the client requests a
# handshake.
server = ScriptedServer(serverscript)
handshakeadapter = InProcessHandshakeAdapter(server)

# Create the WebSocket client, with a custom handshake adapter.
# Instead of making an actual HTTP request, the custom handshake adapter creates an in-process
# `IO` that is used in place of an actual network socket.
# Note that the HTTP handshake logic is still the same, it's only the actual transport method that
# is different.
client = WSClient(; handshake=HTTPHandshake(RandomDevice(), handshakeadapter))

# Create a client that runs the script above.
clienthandler = ScriptedClientHandler(client, clientscript)

# Request that the connection be opened, which starts the scripts for both server and client.
wsconnect(client, "ws://the/uri/does/not/matter/here", clienthandler)

# TODO Remove this debug code once the test is expected to work
@async begin
    sleep(5)
    println("Closing client side connection")
    Stubs.notifyclosed(clienthandler)
    sleep(1)
    println("Closing server side connection")
    Stubs.notifyclosed(server)
end

# Wait for both client and server to close.
waitforscriptdone(server, clienthandler)

@testset "Sent messages" begin
    @test server.statistics.texts_received == 5
end

@testset "Received messages" begin
    @test client.statistics.binaries_received == 5
end