immutable FakeFrameStream <: IO
    reading::Vector{Frame}
    writing::Vector{Frame}
end

function Base.read(s::FakeFrameStream, ::Type{Frame})
    if isempty(s.reading)
        throw(EOFError())
    end
    sleep(0.2)
    shift!(s.reading)
end

function Base.write(s::FakeFrameStream, frame::Frame)
    push!(s.writing, frame)
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

    TestHandler() = new(Vector{UTF8String}(), Channel{Symbol}(5))
end

WebSocketClient.text_received(h::TestHandler, text::UTF8String) = push!(h.received_texts, text)
WebSocketClient.on_close(h::TestHandler) = put!(h.stop_chan, :stop)

wait(t::TestHandler) = take!(t.stop_chan)
function expect_text(t::TestHandler, expected::UTF8String)
    @fact t.received_texts --> x -> !isempty(x)

    actual = shift!(t.received_texts)
    @fact actual --> expected
end

facts("Integration test") do
    context("Receive two Hello messages.") do
        # test_frame1 is a complete text message with payload "Hello".
        # test_frame2 and test_frame3 are two fragments that together become a whole text message
        # also with payload "Hello".
        server_to_client_frames = [test_frame1, test_frame2, test_frame3, server_close_frame]
        stream = FakeFrameStream(server_to_client_frames, Vector{Frame}())
        body = Vector{UInt8}()
        handshake_result = WebSocketClient.HandshakeResult(
            accept, # This is the accept value we expect, and matches that in the headers dict.
            stream,
            headers,
            body)

        do_handshake = () -> handshake_result
        handler = TestHandler()

        client = WSClient(handler, do_handshake)

        # Sleep for a few seconds to let all the messages be sent and received
        sleep(2.0)
        # Wait for the handler to receive close confirmation.
        wait(handler)

        # We expect that the server sent two Hello messages, in three frames.
        # One frame was a complete Hello text message, the other two are fragmented into two parts.
        expect_text(handler, utf8("Hello"))
        expect_text(handler, utf8("Hello"))
    end
end