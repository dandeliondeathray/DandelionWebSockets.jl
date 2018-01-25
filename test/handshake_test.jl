headers = Dict(
    # This is the expected response when the client sends
    # Sec-WebSocket-Key => "dGhlIHNhbXBsZSBub25jZQ=="
    "Sec-WebSocket-Accept" => "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
)

type MockRequest
    accept::String

    uri::Requests.URI
    method::String
    headers::Dict

    MockRequest(accept::String) =
        new(accept, Requests.URI("http://some/uri"), "method", Dict())
end

type FakeResponse
    headers::Dict{Any,Any}
end

type FakeResponseStream
    socket::IO
    response::FakeResponse
end

function mock_do_stream_request(m::MockRequest, uri::Requests.URI, method::String;
    headers=Dict(),
    tls_conf=Requests.TLS_VERIFY,
    response_headers=Dict{Any,Any}())

    m.uri = uri
    m.method = method
    m.headers = headers

    FakeResponseStream(IOBuffer(), FakeResponse(response_headers))
end

facts("Handshake") do
    context("Handshake") do
        rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
        key = "AQIDBAUGBwgJCgsMDQ4PEA=="
        expected_headers = DandelionWebSockets.make_headers(key)
        expected_accept = DandelionWebSockets.calculate_accept(key)
        expected_response_headers = Dict{Any, Any}("some" => "value")

        uri = Requests.URI("http://localhost:8000")

        m = MockRequest(expected_accept)
        function do_req(uri::Requests.URI, method::String; headers=Dict())
            mock_do_stream_request(m, uri, method;
                headers=headers,
                response_headers=expected_response_headers)
        end

        handshake_result = DandelionWebSockets.do_handshake(rng, uri; do_request=do_req)

        @fact m.method --> "GET"
        @fact m.uri --> uri
        @fact m.headers --> expected_headers

        @fact handshake_result.expected_accept --> expected_accept
        @fact handshake_result.headers --> expected_response_headers
    end

    context("SSL handshakes result in a TLSBufferedIO stream") do
        rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
        key = "AQIDBAUGBwgJCgsMDQ4PEA=="
        expected_accept = DandelionWebSockets.calculate_accept(key)

        uri = Requests.URI("http://localhost:8000")
        ssl_uri = Requests.URI("https://localhost:8000")

        m = MockRequest(expected_accept)
        do_req(uri::Requests.URI, method::String; headers=Dict()) =
            mock_do_stream_request(m, uri, method; headers=headers)

        normal_handshake_result = DandelionWebSockets.do_handshake(rng, uri; do_request=do_req)
        @fact isa(normal_handshake_result.stream, DandelionWebSockets.TLSBufferedIO) --> false

        rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
        ssl_handshake_result = DandelionWebSockets.do_handshake(rng, ssl_uri, do_request=do_req)
        @fact isa(ssl_handshake_result.stream, DandelionWebSockets.TLSBufferedIO) --> true
    end
end
