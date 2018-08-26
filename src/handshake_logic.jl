using Random
using Base64
using SHA

const HeaderList = AbstractArray{Pair{String, String}}

abstract type HandshakeValidationResult end
struct UnsuccessfulHandshake <: HandshakeValidationResult end
struct SuccessfulHandshake <: HandshakeValidationResult end

issuccessful(::UnsuccessfulHandshake) = false
issuccessful(::SuccessfulHandshake) = true

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

function _expectheader(headers::HeaderList, name::String, value::String) :: Bool
    for (k, v) in headers
        if lowercase(k) == lowercase(name) && lowercase(value) == lowercase(v)
            return true
        end
    end
    return false
end

function validateresponse(h::HTTPHandshakeLogic, statuscode::Int, headers::HeaderList)
    if statuscode != 101
        return UnsuccessfulHandshake()
    end

    if !_expectheader(headers, "Upgrade", "websocket")
        return UnsuccessfulHandshake()
    end

    if !_expectheader(headers, "Connection", "Upgrade")
        return UnsuccessfulHandshake()
    end

    expectedaccept = base64encode(sha1(h.key * "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
    if !_expectheader(headers, "Sec-WebSocket-Accept", expectedaccept)
        return UnsuccessfulHandshake()
    end

    SuccessfulHandshake()
end
