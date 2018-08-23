using Random
using Base64

abstract type HTTPHandshakeValidationResult end
struct BadHTTPHandshake <: HTTPHandshakeValidationResult end
struct GoodHTTPHandshake <: HTTPHandshakeValidationResult end

issuccessful(::BadHTTPHandshake) = false
issuccessful(::GoodHTTPHandshake) = true

struct HTTPHandshakeLogic
    rng::AbstractRNG
end

getrequestheaders(h::HTTPHandshakeLogic) = [
    "Sec-WebSocket-Version" => "13",
    "Upgrade" => "websocket",
    "Connection" => "Upgrade",
    "Sec-WebSocket-Key" => base64encode(rand(h.rng, UInt8, 16))]

function _expectheader(headers::AbstractArray{Pair{String, String}}, name::String, value::String) :: Bool
    for (k, v) in headers
        if k == name && lowercase(value) == lowercase(v)
            return true
        end
    end
    return false
end

function validateresponse(::HTTPHandshakeLogic, statuscode::Int, headers::AbstractArray{Pair{String, String}})
    if statuscode != 101
        return BadHTTPHandshake()
    end

    if !_expectheader(headers, "Upgrade", "websocket")
        return BadHTTPHandshake()
    end

    if !_expectheader(headers, "Connection", "Upgrade")
        return BadHTTPHandshake()
    end

    GoodHTTPHandshake()
end
