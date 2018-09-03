using HTTP
using Random

"HTTPUpgradeResponse is a collection of data returned by a HTTP upgrade, regardless of package."
struct HTTPUpgradeResponse
    io::IO
    statuscode::Int
    headers::HeaderList
    excess::AbstractVector{UInt8}
end

"""
HTTPAdapter is an abstract type for an HTTP package that can be used for a handshake GET.

Any subtype of HTTPAdapter should implement the `dohandshake` method.
"""
abstract type HTTPAdapter end

"""
    dohandshake(http::HTTPAdapter, uri::String, headers::HeaderList)

Do an HTTP GET request to `uri` including headers `headers`.

The `headers` list will contain all WebSocket upgrade specific headers, such as `Connection`,
`Upgrade`, and `Sec-WebSocket-Key`.
"""
dohandshake(::HTTPAdapter, uri::String, headers::HeaderList) :: HTTPUpgradeResponse = error("Implement this in your subtype")

"AbstractHandshakeResult is a  supertype for either a successful or an unsuccessful handshake."
abstract type AbstractHandshakeResult end

"GoodHandshake is returned when a successful handshake has been made."
struct GoodHandshake <: AbstractHandshakeResult
    # The socket to use for all WebSocket communication.
    io::IO

    # Any excess bytes read from the socket during the handshake, that should actually be part of
    # the WebSocket communication.
    excess::AbstractVector{UInt8}
end

"BadHandshake is returned when an unsuccessful handshake has been made."
struct BadHandshake <: AbstractHandshakeResult end

"""
    issuccessful(::AbstractHandshakeResult)

True if a handshake was succcessful, false otherwise.
"""
issuccessful(::GoodHandshake) = true
issuccessful(::BadHandshake) = false

"""WebSocketHandshake represents a way to make a WebSocket connection handshake.

The only handshake detailed in the specification is an HTTP handshake, represented by the
`HTTPHandshake` type (regardless of HTTP package used to implement it). The specification does
mention the possibility of other types of handshakes, even though these would be outside of the
specification.
"""
abstract type WebSocketHandshake end

"""HTTPHandshake implements the HTTP handshake from the WebSocket specification.

It requires a random number generator to generate the WebSocket random key used to verify that the
other side is actually a WebSocket server. The `HTTPAdapter` supplied implements the actual HTTP
GET request, which returns an `HTTPUpgradeResponse`.
"""
struct HTTPHandshake <: WebSocketHandshake
    handshakelogic::HTTPHandshakeLogic
    http::HTTPAdapter

    HTTPHandshake(rng::Random.AbstractRNG, http::HTTPAdapter) = new(HTTPHandshakeLogic(rng), http)
end

"""
    performhandshake(h::HTTPHandshake, uri::String)

Do a handshake with the server at `uri`, with parameters supplied by `h`. Validate the handshake,
and return a good or bad result, depending on the validation.
"""
function performhandshake(h::HTTPHandshake, uri::String) :: AbstractHandshakeResult
    try
        upgraderesponse = dohandshake(h.http, uri, getrequestheaders(h.handshakelogic))
        validation = validateresponse(h.handshakelogic, upgraderesponse.statuscode, upgraderesponse.headers)
        if issuccessful(validation)
            GoodHandshake(upgraderesponse.io, upgraderesponse.excess)
        else
            BadHandshake()
        end
    catch ex
        println("Exception: $ex")
        BadHandshake()
    end
end

#
# Integration with HTTP.jl
#
# This implements the handshake HTTP request using the HTTP.jl package.
#

# Side note: The name `HTTPjlAdapter` isn't great, but not worse than `HTTPHTTPAdapter`.
struct HTTPjlAdapter <: HTTPAdapter end

function dohandshake(::HTTPjlAdapter, uri::String, headers::HeaderList) :: HTTPUpgradeResponse
    socket, response, excess = HTTP.openraw("GET", uri, headers)
    responseheaders = [String(a) => String(b) for (a, b) in response.headers]

    HTTPUpgradeResponse(socket, response.status, response.headers, excess)
end