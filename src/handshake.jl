import Nettle
import Requests

"Keeps the result of a HTTP Upgrade attempt, when converting a HTTP connection to a WebSocket."
immutable HandshakeResult
    # The expected `Sec-WebSocket-Accept` value. See `validate`.
    expected_accept::ASCIIString

    # The network stream opened by Requests, that we'll use for the WebSocket protocol.
    stream::IO

    # Response headers, keeping the WebSocket accept value, among others.
    headers::Dict{ASCIIString,ASCIIString}

    # When doing the HTTP upgrade, we might have read a part of the first WebSocket frame. This
    # contains that data.
    body::Vector{UInt8}
end

# Currently only used to dispatch a failed HTTP upgrade to another function.
immutable HandshakeFailure

end

"""
The WebSocket server is expected to reply with a computed value to prove that it's actually a
WebSocket server, and not another server duped into accepting this HTTP upgrade. This function
validates that the expected computed value is found in the response headers.
"""
function validate(handshake::HandshakeResult)
    accept_name = "Sec-WebSocket-Accept"
    if !haskey(handshake.headers, accept_name)
        println("No key $accept_name in $(handshake.headers)")
        return false
    end

    accept_value = handshake.headers[accept_name]

    is_valid = accept_value == handshake.expected_accept
    if !is_valid
        println("Expected accept value $(handshake.expected_accept) does not match actual $accept_value")
    end

    is_valid
end

"Create a random key that the server will use to compute its response."
function make_websocket_key(rng::AbstractRNG)
    ascii(base64encode(rand(rng, UInt8, 16)))
end

"Calculate the accept value, given the random key supplied by the client."
function calculate_accept(key::ASCIIString)
    magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    h = Nettle.digest("sha1", key * magic)
    base64encode(h)
end

"Create headers used to upgrade the HTTP connection to a WebSocket connection."
function make_headers(key::ASCIIString)
    headers = Dict(
        "Upgrade" => "websocket",
        "Connection" => "Upgrade",
        "Sec-WebSocket-Key" => key,
        "Sec-WebSocket-Version" => "13")
end

"Make a HTTP connection and upgrade it to a WebSocket connection."
function do_handshake(rng::AbstractRNG, uri::Requests.URI; do_request=Requests.do_stream_request)
    key = make_websocket_key(rng)
    expected_accept = calculate_accept(key)
    headers = make_headers(key)
    result = do_request(uri, ascii("GET"); headers=headers)

    stream = result.socket
    if uri.scheme == "https"
        stream = TLSBufferedIO(stream)
    end

    # TODO: Headers are not returned yet. This prevents us from actually validating the connection.
    # TODO: Any body unintentionally read during the HTTP parsing is not returned, which means that
    #       if any such bytes were read, then we will not be able to correctly read the first frame.
    HandshakeResult(expected_accept, stream, Dict(), b"")
end

"Convert `ws://` or `wss://` URIs to 'http://` or `https://`."
function convert_ws_uri(uri::Requests.URI)
    u = replace(string(uri), r"^ws", "http")
    Requests.URI(u)
end