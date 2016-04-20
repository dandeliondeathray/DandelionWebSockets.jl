headers = Dict(
    # This is the expected response when the client sends
    # Sec-WebSocket-Key => "dGhlIHNhbXBsZSBub25jZQ=="
    "Sec-WebSocket-Accept" => "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
)

facts("Handshake") do
    context("Validation") do
        stream = IOBuffer()
        ok_handshake = WebSocketClient.HandshakeResult(
            "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",
            stream,
            headers,
            [])

        bad_handshake = WebSocketClient.HandshakeResult(
            "notagoodreply",
            stream,
            headers,
            [])

        missing_header = WebSocketClient.HandshakeResult(
            "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",
            stream,
            Dict(),
            [])

        @fact ok_handshake --> WebSocketClient.validate
        @fact bad_handshake --> x -> !WebSocketClient.validate(x)
        @fact missing_header --> x -> !WebSocketClient.validate(x)
    end

    context("Handshake calculations") do
        rng = FakeRNG(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
        actual_key = WebSocketClient.make_websocket_key(rng)
        @fact actual_key --> ascii("AQIDBAUGBwgJCgsMDQ4PEA==")

        key = ascii("dGhlIHNhbXBsZSBub25jZQ==")
        @fact WebSocketClient.calculate_accept(key) --> "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
    end
end