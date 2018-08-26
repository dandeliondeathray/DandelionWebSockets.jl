import SHA
using HTTP
using Base64
using Random

"Keeps the result of a HTTP Upgrade attempt, when converting a HTTP connection to a WebSocket."
struct HandshakeResult
    # The expected `Sec-WebSocket-Accept` value. See `validate`.
    expected_accept::String

    # The network stream opened by Requests, that we'll use for the WebSocket protocol.
    stream::IO

    # Response headers, keeping the WebSocket accept value, among others.
    headers::Dict{String, String}

    # When doing the HTTP upgrade, we might have read a part of the first WebSocket frame. This
    # contains that data.
    body::Vector{UInt8}
end

# Currently only used to dispatch a failed HTTP upgrade to another function.
struct HandshakeFailure

end

"""
The WebSocket server is expected to reply with a computed value to prove that it's actually a
WebSocket server, and not another server duped into accepting this HTTP upgrade. This function
validates that the expected computed value is found in the response headers.
"""
function validate(handshake::HandshakeResult)
    normal_keys = collect(keys(handshake.headers))
    lower_keys = map(lowercase, normal_keys)
    accept_name_index = findfirst(isequal("sec-websocket-accept"), lower_keys)
    if accept_name_index == nothing
        return false
    end

    accept_name = normal_keys[accept_name_index]
    accept_value = handshake.headers[accept_name]

    is_valid = accept_value == handshake.expected_accept

    is_valid
end

"Create a random key that the server will use to compute its response."
function make_websocket_key(rng::AbstractRNG)
    base64encode(rand(rng, UInt8, 16))
end

"Calculate the accept value, given the random key supplied by the client."
function calculate_accept(key::String)
    magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    base64encode(SHA.sha1(key * magic))
end

"Create headers used to upgrade the HTTP connection to a WebSocket connection."
function make_headers(key::String)
    headers = Dict(
        "Upgrade" => "websocket",
        "Connection" => "Upgrade",
        "Sec-WebSocket-Key" => key,
        "Sec-WebSocket-Version" => "13")
end

mutable struct HandshakeStreamResult
    stream::Union{IO,Nothing}
end

"Make a HTTP connection and upgrade it to a WebSocket connection."
function do_handshake(rng::AbstractRNG, uri::String; do_request=HTTP.open)
    # Requirement
    # @4_1_OpeningHandshake_1 Opening handshake is a valid HTTP request
    # @4_1_OpeningHandshake_4 Opening handshake Host header field
    # @4_1_OpeningHandshake_7-2 Opening handshake Sec-WebSocket-Key header field is randomly chosen
    #
    # Covered by design, as we use HTTP.jl, which can be assumed to make valid HTTP requests.

    handshakestreamresult = HandshakeStreamResult(nothing)
    key = make_websocket_key(rng)
    expected_accept = calculate_accept(key)
    headers = make_headers(key)
    result = do_request("GET", uri, headers; reuse_limit=0, keep_open=true) do http
        HTTP.startread(http)
        handshakestreamresult.stream = HTTP.ConnectionPool.getrawstream(http)
    end

    if startswith(uri, "https://")
        handshakestreamresult.stream = TLSBufferedIO(handshakestreamresult.stream)
    end

    responseheaders = Dict{String, String}([String(a) => String(b) for (a, b) in result.headers])

    # TODO: Any body unintentionally read during the HTTP parsing is not returned, which means that
    #       if any such bytes were read, then we will not be able to correctly read the first frame.
    HandshakeResult(expected_accept, handshakestreamresult.stream, responseheaders, b"")
end

"Convert `ws://` or `wss://` URIs to 'http://` or `https://`."
function convert_ws_uri(uri::String)
    replace(uri, r"^ws" => "http")
end

#
# New implementation of the handshake.
#
struct HTTPUpgradeResponse
    io::IO
    statuscode::Int
    headers::HeaderList
end

abstract type HTTPAdapter end
dohandshake(::HTTPAdapter, headers::HeaderList) :: HTTPUpgradeResponse = error("Implement this in your subtype")

struct HTTPHandshake
    handshakelogic::HTTPHandshakeLogic
    http::HTTPAdapter

    HTTPHandshake(rng::Random.AbstractRNG, http::HTTPAdapter) = new(HTTPHandshakeLogic(rng), http)
end


function performhandshake(h::HTTPHandshake) :: HandshakeValidationResult
    upgraderesponse = dohandshake(h.http, getrequestheaders(h.handshakelogic))
    validateresponse(h.handshakelogic, upgraderesponse.statuscode, upgraderesponse.headers)
end