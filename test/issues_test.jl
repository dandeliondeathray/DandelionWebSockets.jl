using Test
using DandelionWebSockets
using DandelionWebSockets: HTTPAdapter, HeaderList, HTTPHandshake, HTTPUpgradeResponse
import DandelionWebSockets: dohandshake, state_connecting

"FakeHTTPAdapter lets us control the handshake response in a test."
struct FakeHTTPAdapter <: HTTPAdapter
    response::HTTPUpgradeResponse
end
dohandshake(adapter::FakeHTTPAdapter, ::String, ::HeaderList) = adapter.response 

"NothingWebSocketHandler is a handler that does nothing, but storing the connection. The default
implementations do nothing."
mutable struct NothingWebSocketHandler <: WebSocketHandler
    connection::Union{WebSocketConnection, Nothing}
    chanstop::Channel{Nothing}
    NothingWebSocketHandler() = new(nothing, Channel{Nothing}(0))
end
state_connecting(h::NothingWebSocketHandler, conn::WebSocketConnection) = h.connection = conn
state_closed(h::NothingWebSocketHandler) = put!(h.chanstop, nothing)
waitforclose(h::NothingWebSocketHandler) = take!(h.chanstop)

@testset "Issues                 " begin
    @testset "Issue #12: Masking frames should be done on a copy of data" begin
        # Arrange
        logic, handler, writer = makeclientlogic()

        text = "Foo"

        # Act
        handle(logic, SendTextFrame(text, true, OPCODE_TEXT))

        # Assert
        @test text == "Foo"
    end

    @testset "Issue #43: `stop`, on a WebSocketConnection that never opened, fails" begin
        # Arrange
        # Status code 200 will cause the handshake to be invalid.
        handshakeadapter = FakeHTTPAdapter(HTTPUpgradeResponse(IOBuffer(), 200, [], b""))
        handshake = HTTPHandshake(RandomDevice(), handshakeadapter)

        handler = NothingWebSocketHandler()
        client = WSClient(; handshake=handshake)

        # This connection will fail, because the handshake returned HTTP status code 200.
        wsconnect(client, "http://some/uri", handler)
        # Wait for the connection state to become closed.
        waitforclose(handler)

        # Act
        stop(handler.connection)

        # Assert
        # No assert, because the above call will throw an exception in the presence of issue #43.
    end
end