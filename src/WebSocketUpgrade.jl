module WebSocketUpgrade

export ResponseParser, dataread, hascompleteresponse, parseresponse, findheader

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

const HeaderList = Vector{Pair{String, String}}

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

function findheader(response::HTTPResponse, name::String) :: Union{String, Nothing}
    for h in response.headers
        if h[1] == name
            return h[2]
        end
    end
end

struct BadHTTPResponse <: Exception end

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

        return HTTPResponse(status, reasonphrase, headers, HTTPVersion(major, minor))
    end

    throw(BadHTTPResponse())
end

end