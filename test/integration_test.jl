import DandelionWebSockets: on_text, on_binary,
                            state_connecting, state_open, state_closing, state_closed,
                            FrameFromServer

accept_field = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
headers = Dict(
    # This is the expected response when the client sends
    # Sec-WebSocket-Key => "dGhlIHNhbXBsZSBub25jZQ=="
    "Sec-WebSocket-Accept" => accept_field
)

type TestHandler <: WebSocketHandler
    received_texts::Vector{UTF8String}
    received_datas::Vector{Vector{UInt8}}
    stop_chan::Channel{Symbol}
    close_on_message::Bool # If true, initiates a closing handshake on the first message.
    client::WSClient
    is_closed::Bool

    TestHandler(client::WSClient) = new(Vector{UTF8String}(), [], Channel{Symbol}(5), false, client, false)
    TestHandler(client::WSClient, close_on_message::Bool) =
        new(Vector{UTF8String}(), [], Channel{Symbol}(5), close_on_message, client, false)
end

function on_text(h::TestHandler, text::UTF8String)
    push!(h.received_texts, text)
    if h.close_on_message
        stop(h.client)
    end
end


function on_binary(h::TestHandler, data::Vector{UInt8})
    push!(h.received_datas, data)
    if h.close_on_message
        stop(h.client)
    end
end

state_open(h::TestHandler) = nothing
state_connecting(h::TestHandler) = nothing
state_closing(h::TestHandler) = nothing
function state_closed(h::TestHandler)
    h.is_closed = true
    put!(h.stop_chan, :stop)
end

wait(t::TestHandler) = take!(t.stop_chan)
function expect_text(t::TestHandler, expected::UTF8String)
    @fact t.received_texts --> not(isempty)

    actual = shift!(t.received_texts)
    @fact actual --> expected
end

function expect_binary(t::TestHandler, expected::Vector{UInt8})
    @fact t.received_datas --> x -> !isempty(x)

    actual = shift!(t.received_datas)
    @fact actual --> expected
end

uri = Requests.URI("http://some/host")

immutable FakeHandler <: WebSocketHandler end


facts("Integration test") do
    context("Receive two Hello messages, and one binary.") do
        # test_frame1 is a complete text message with payload "Hello".
        # test_frame2 and test_frame3 are two fragments that together become a whole text message
        # also with payload "Hello". frame_bin_1 is a binary message.
        server_to_client_frames = [test_frame1, test_frame2, test_frame3,
                                   frame_bin_1, server_close_frame]
        stream = FakeFrameStream(server_to_client_frames, Vector{Frame}(), true)

        body = Vector{UInt8}()
        handshake_result = DandelionWebSockets.HandshakeResult(
            accept_field, # This is the accept value we expect, and matches that in the headers dict.
            stream,
            headers,
            body)

        do_handshake = (rng::AbstractRNG, uri::Requests.URI) -> handshake_result

        client = WSClient(; do_handshake=do_handshake)
        handler = TestHandler(client)
        wsconnect(client, uri, handler)

        # Write a message "Hello"
        send_text(client, utf8("Hello"))
        send_binary(client, b"Hello, binary")

        # Sleep for a few seconds to let all the messages be sent and received
        sleep(2.0)
        # Wait for the handler to receive close confirmation.
        wait(handler)

        # We expect that the server sent two Hello messages, in three frames.
        # One frame was a complete Hello text message, the other two are fragmented into two parts.
        expect_text(handler, utf8("Hello"))
        expect_text(handler, utf8("Hello"))
        expect_binary(handler, b"Hello")

        # We expect one text message "Hello", one binary message, and one close control frame to
        # have been sent.
        @fact length(stream.writing) --> 3
    end

    context("Reconnect the client") do
        # test_frame1 is a complete text message with payload "Hello".
        # test_frame2 and test_frame3 are two fragments that together become a whole text message
        # also with payload "Hello". frame_bin_1 is a binary message.
        server_to_client_frames = [test_frame1, test_frame2, test_frame3,
                                   frame_bin_1, server_close_frame]
        stream = FakeFrameStream(server_to_client_frames, Vector{Frame}(), true)

        body = Vector{UInt8}()
        handshake_result = DandelionWebSockets.HandshakeResult(
            accept_field, # This is the accept value we expect, and matches that in the headers dict.
            stream,
            headers,
            body)

        do_handshake = (rng::AbstractRNG, uri::Requests.URI) -> handshake_result

        client = WSClient(; do_handshake=do_handshake)
        handler = TestHandler(client)
        wsconnect(client, uri, handler)

        # Write a message "Hello"
        send_text(client, utf8("Hello"))

        # Sleep for a few seconds to let all the messages be sent and received
        sleep(2.0)
        # Wait for the handler to receive close confirmation.
        wait(handler)

        # Connect again.
        wsconnect(client, uri, handler)
        send_text(client, utf8("Hello"))
        # Sleep for a few seconds to let all the messages be sent and received
        sleep(2.0)
        # Wait for the handler to receive close confirmation.
        wait(handler)

        # We expect one text message "Hello", one binary message, and one close control frame to
        # have been sent.
        @fact length(stream.writing) --> 3
    end

    context("The client initiates closing handshake") do
        # test_frame1 is a complete text message with payload "Hello".
        # test_frame2 and test_frame3 are two fragments that together become a whole text message
        # also with payload "Hello".
        server_to_client_frames = [test_frame1, server_close_frame]
        stream = FakeFrameStream(server_to_client_frames, Vector{Frame}(), false)

        body = Vector{UInt8}()
        handshake_result = DandelionWebSockets.HandshakeResult(
            accept_field, # This is the accept value we expect, and matches that in the headers dict.
            stream,
            headers,
            body)

        websocket_uri = Requests.URI("wss://some/uri")
        expected_uri = Requests.URI("https://some/uri")
        handshake_uri = nothing

        function do_handshake(rng::AbstractRNG, uri::Requests.URI)
            handshake_uri = uri
            handshake_result
        end

        client = WSClient(; do_handshake=do_handshake)
        handler = TestHandler(client, true)
        wsconnect(client, websocket_uri, handler)

        @fact handshake_uri --> expected_uri

        # Send a message "Hello" from client to server.
        send_text(client, utf8("Hello"))
        # Send a message "world" from client to server.
        send_text(client, utf8("world"))

        # Sleep for a few seconds to let all the messages be sent and received
        sleep(1.0)
        # Wait for the handler to receive close confirmation.
        wait(handler)

        # We expect that the server sent two Hello messages, in three frames.
        # One frame was a complete Hello text message, the other two are fragmented into two parts.
        expect_text(handler, utf8("Hello"))

        # We expect one close frame and two message "Hello" and "world" to have been sent.
        @fact length(stream.writing) --> 3
    end

    context("Client is disconnected when no pongs are received") do
        # test_frame1 is a complete text message with payload "Hello".
        # test_frame2 and test_frame3 are two fragments that together become a whole text message
        # also with payload "Hello". frame_bin_1 is a binary message.
        stream = FakeFrameStream(Vector{Frame}(), Vector{Frame}(), false)

        body = Vector{UInt8}()
        handshake_result = DandelionWebSockets.HandshakeResult(
            accept_field, # This is the accept value we expect, and matches that in the headers dict.
            stream,
            headers,
            body)

        do_handshake = (rng::AbstractRNG, uri::Requests.URI) -> handshake_result

        pong_timeout = 0.2
        ping_interval = 0.4
        client = WSClient(; do_handshake=do_handshake,
                            ponger=Ponger(pong_timeout),
                            pinger=Pinger(ping_interval))
        handler = TestHandler(client)
        wsconnect(client, uri, handler)

        # Send two pings 0.4 seconds apart. The first receives a pong 0.1 seconds after it's sent.
        # The other ping never receives a pong reply. We expect the connection to close 0.2 seconds
        # after the second ping was sent, because pong_timeout = 0.2 above.
        handle(client.logic_proxy, ClientPingRequest())
        sleep(pong_timeout / 2.0)

        # Bypass network and inject a pong directly into the client logic, because it's much
        # simpler.
        handle(client.logic_proxy, FrameFromServer(server_pong_frame))

        sleep(0.2)

        handle(client.logic_proxy, ClientPingRequest())
        sleep(pong_timeout / 2.0)
        handle(client.logic_proxy, FrameFromServer(server_pong_frame))

        # Now we send a ping, but never injecting a pong. This should cause the connection to close.
        handle(client.logic_proxy, ClientPingRequest())
        sleep(pong_timeout * 2.0)

        @fact handler.is_closed --> true
    end

    context("Check that default callbacks do nothing") do
        h = FakeHandler()
        on_text(h, utf8("Hello"))
        on_binary(h, b"Hello")
        state_closed(h)
        state_closing(h)
        state_connecting(h)
        state_open(h)
    end
end
