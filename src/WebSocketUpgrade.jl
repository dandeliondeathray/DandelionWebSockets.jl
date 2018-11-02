module WebSocketUpgrade

using DandelionWebSockets.UniformResourceIdentifiers
using Sockets

export ResponseParser, dataread, hascompleteresponse, parseresponse, findheaderfield
export websocketupgrade

const HeaderList = Vector{Pair{String, String}}

struct Request
    host::String
    abs_path::String
    headers::HeaderList
end

function Base.write(io::IO, req::Request)
    write(io, "GET $(req.abs_path) HTTP/1.1\r\n")
    write(io, "Host: $(req.host)\r\n")
    for (k, v) in req.headers
        write(io, "$(k): $(v)\r\n")
    end
    write(io, "\r\n")
end

function findfirstsubstring(needle::AbstractVector{UInt8}, haystack::AbstractVector{UInt8}) :: Union{Int, Nothing}
    lastpossibleindex = length(haystack) - length(needle) + 1
    for i = 1:lastpossibleindex
        substring = haystack[i:i + length(needle) - 1]
        if substring == needle
            return i
        end
    end
    nothing
end

struct ResponseParser
    data::Vector{UInt8}

    ResponseParser() = new(Vector{UInt8}())
end

struct HTTPVersion
    major::Int
    minor::Int
end
struct HTTPResponse
    status::Int
    reasonphrase::String
    headers::HeaderList
    httpversion::HTTPVersion
end

function findheaderfield(response::HTTPResponse, name::String) :: Union{String, Nothing}
    for h in response.headers
        if h[1] == name
            return h[2]
        end
    end
end

struct BadHTTPResponse <: Exception end
struct InvalidHTTPResponse <: Exception end

hastoken(response::HTTPResponse, fieldname::String, token::String) = occursin(token, findheaderfield(response, fieldname))

function validateresponse(response::HTTPResponse) :: HTTPResponse
    hasupgrade = findheaderfield(response, "Upgrade") != nothing
    hasconnection = findheaderfield(response, "Connection") != nothing
    if hasupgrade && !hasconnection
        @error "Found Upgrade header, but not Connection header."
        throw(InvalidHTTPResponse())
    end

    if hasupgrade && hasconnection
        hasconnectionupgrade = hastoken(response, "Connection", "Upgrade")
        if !hasconnectionupgrade
            @error "Connection header does not have the token 'upgrade'"
            throw(InvalidHTTPResponse())
        end
    end

    response
end

dataread(parser::ResponseParser, data::AbstractVector{UInt8}) = append!(parser.data, data)
hascompleteresponse(parser::ResponseParser) = findfirstsubstring(b"\r\n\r\n", parser.data) != nothing
function parseresponse(parser::ResponseParser)
    endofheader = findfirstsubstring(b"\r\n\r\n", parser.data)
    headerbytes = parser.data[1:endofheader-1]
    header = String(headerbytes)
    headerlines = split(header, "\r\n")
    statusline = headerlines[1]

    statuslinematch = match(r"^HTTP/([0-9]+)\.([0-9]+) +([0-9]+) +([^\r\n]*)", statusline)
    if statuslinematch != nothing
        status = parse(Int, statuslinematch.captures[3])
        reasonphrase = statuslinematch.captures[4]
        major = parse(Int, statuslinematch.captures[1])
        minor = parse(Int, statuslinematch.captures[2])

        headers = []
        headerregex = r"([^:]+): (.*)"
        for line in headerlines[2:end]
            m = match(headerregex, line)
            push!(headers, m.captures[1] => m.captures[2])
        end

        return validateresponse(HTTPResponse(status, reasonphrase, headers, HTTPVersion(major, minor)))
    end

    throw(BadHTTPResponse())
end

function websocketupgrade(suri::String, headers::HeaderList)
    uri = URI(suri)
    socket = connect(uri.host, uri.port)
    upgraderequest = Request(uri.host, uri.abs_path, headers)
    write(socket, upgraderequest)
    isheadercomplete = false
    parser = ResponseParser()
    while !isheadercomplete
        if eof(socket)
            throw(EOFError())
        end
        data = readavailable(socket)
        dataread(parser, data)
        isheadercomplete = hascompleteresponse(parser)
    end
    # TODO: No excess returned
    response = parseresponse(parser)
    (response, socket)
end

end