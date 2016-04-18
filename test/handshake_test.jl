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
        @fact missing_header --> x -> !WebSocketClient.validate(x)1
    end
end