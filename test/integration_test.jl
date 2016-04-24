immutable FakeFrameStream <: IO
    reading::Vector{Frame}
    writing::Vector{Frame}
    close_on_empty::Bool
    stop_chan::Channel{Symbol}

    FakeFrameStream(reading::Vector{Frame}, writing::Vector{Frame}, close_on_empty::Bool) =
        new(reading, writing, close_on_empty, Channel{Symbol}(32))
end

function Base.read(s::FakeFrameStream, ::Type{Frame})
    if isempty(s.reading)
        if s.close_on_empty
            throw(EOFError())
        else
            take!(s.stop_chan)
            throw(EOFError())
        end
    end
    sleep(0.2)
    shift!(s.reading)
end

function Base.write(s::FakeFrameStream, frame::Frame)
    push!(s.writing, frame)
    if frame.opcode == WebSocketClient.OPCODE_CLOSE
        put!(s.stop_chan, :stop)
    end
end

accept = ascii("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
headers = Dict(
    # This is the expected response when the client sends
    # Sec-WebSocket-Key => "dGhlIHNhbXBsZSBub25jZQ=="
    "Sec-WebSocket-Accept" => accept
)

type TestHandler <: WebSocketHandler
    received_texts::Vector{UTF8String}
    stop_chan::Channel{Symbol}
    close_on_message::Bool # If true, initiates a closing handshake on the first text message.
    client::Nullable{WSClient}

    TestHandler() = new(Vector{UTF8String}(), Channel{Symbol}(5), false, nothing)
    TestHandler(close_on_message::Bool) =
        new(Vector{UTF8String}(), Channel{Symbol}(5), close_on_message, nothing)
end

function WebSocketClient.on_text(h::TestHandler, text::UTF8String)
    push!(h.received_texts, text)
    if h.close_on_message
        stop(get(h.client))
    end
end

WebSocketClient.on_closing(h::TestHandler) = nothing
WebSocketClient.on_close(h::TestHandler) = put!(h.stop_chan, :stop)
WebSocketClient.on_create(h::TestHandler, c::WSClient) = h.client = c

wait(t::TestHandler) = take!(t.stop_chan)
function expect_text(t::TestHandler, expected::UTF8String)
    @fact t.received_texts --> x -> !isempty(x)

    actual = shift!(t.received_texts)
    @fact actual --> expected
end

uri = Requests.URI("http://some/host")

facts("Integration test") do
    context("Receive two Hello messages.") do
        # test_frame1 is a complete text message with payload "Hello".
        # test_frame2 and test_frame3 are two fragments that together become a whole text message
        # also with payload "Hello".
        server_to_client_frames = [test_frame1, test_frame2, test_frame3, server_close_frame]
        stream = FakeFrameStream(server_to_client_frames, Vector{Frame}(), true)
        body = Vector{UInt8}()
        handshake_result = WebSocketClient.HandshakeResult(
            accept, # This is the accept value we expect, and matches that in the headers dict.
            stream,
            headers,
            body)

        do_handshake = (rng::AbstractRNG, uri::Requests.URI) -> handshake_result
        handler = TestHandler()

        client = WSClient(uri, handler; do_handshake=do_handshake)

        # Write a message "Hello"
        send_text(client, utf8("Hello"))

        # Sleep for a few seconds to let all the messages be sent and received
        sleep(2.0)
        # Wait for the handler to receive close confirmation.
        wait(handler)

        # We expect that the server sent two Hello messages, in three frames.
        # One frame was a complete Hello text message, the other two are fragmented into two parts.
        expect_text(handler, utf8("Hello"))
        expect_text(handler, utf8("Hello"))

        # We expect one message "Hello" and one close control frame to have been sent.
        @fact length(stream.writing) --> 2
    end

    context("The client initiates closing handshake") do
        # test_frame1 is a complete text message with payload "Hello".
        # test_frame2 and test_frame3 are two fragments that together become a whole text message
        # also with payload "Hello".
        server_to_client_frames = [test_frame1, server_close_frame]
        stream = FakeFrameStream(server_to_client_frames, Vector{Frame}(), false)
        body = Vector{UInt8}()
        handshake_result = WebSocketClient.HandshakeResult(
            accept, # This is the accept value we expect, and matches that in the headers dict.
            stream,
            headers,
            body)

        do_handshake = (rng::AbstractRNG, uri::Requests.URI) -> handshake_result
        handler = TestHandler(true)

        client = WSClient(uri, handler; do_handshake=do_handshake)

        # Write a message "Hello"
        send_text(client, utf8("Hello"))
        # Write a message "Hello"
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
end