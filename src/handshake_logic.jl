using Random
using Base64
using SHA

abstract type HTTPHandshakeValidationResult end
struct BadHTTPHandshake <: HTTPHandshakeValidationResult end
struct GoodHTTPHandshake <: HTTPHandshakeValidationResult end

issuccessful(::BadHTTPHandshake) = false
issuccessful(::GoodHTTPHandshake) = true

struct HTTPHandshakeLogic
    key::String

    function HTTPHandshakeLogic(rng::AbstractRNG)
        new(base64encode(rand(rng, UInt8, 16)))
    end
end

getrequestheaders(h::HTTPHandshakeLogic) = [
    "Sec-WebSocket-Version" => "13",
    "Upgrade" => "websocket",
    "Connection" => "Upgrade",
    "Sec-WebSocket-Key" => h.key]

function _expectheader(headers::AbstractArray{Pair{String, String}}, name::String, value::String) :: Bool
    for (k, v) in headers
        if k == name && lowercase(value) == lowercase(v)
            return true
        end
    end
    return false
end

function validateresponse(h::HTTPHandshakeLogic, statuscode::Int, headers::AbstractArray{Pair{String, String}})
    if statuscode != 101
        return BadHTTPHandshake()
    end

    if !_expectheader(headers, "Upgrade", "websocket")
        return BadHTTPHandshake()
    end

    if !_expectheader(headers, "Connection", "Upgrade")
        return BadHTTPHandshake()
    end

    expectedaccept = base64encode(sha1(h.key * "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
    if !_expectheader(headers, "Sec-WebSocket-Accept", expectedaccept)
        return BadHTTPHandshake()
    end

    GoodHTTPHandshake()
end
