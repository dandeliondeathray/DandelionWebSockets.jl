module WebSocketUpgrade

export ResponseParser, dataread, hascompleteresponse, parseresponse

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

struct HTTPResponse
    status::Int
    reasonphrase::String
end

struct BadHTTPResponse <: Exception end

dataread(parser::ResponseParser, data::AbstractVector{UInt8}) = append!(parser.data, data)
hascompleteresponse(parser::ResponseParser) = findfirstsubstring(b"\r\n\r\n", parser.data) != nothing
function parseresponse(parser::ResponseParser)
    endofheader = findfirstsubstring(b"\r\n\r\n", parser.data)
    headerbytes = parser.data[1:endofheader]
    header = String(headerbytes)
    headerlines = split(header, "\r\n\r\n")
    statusline = headerlines[1]

    statuslinematch = match(r"^HTTP/1.1 +([0-9]+) +([^\r\n]*)", statusline)
    if statuslinematch != nothing
        status = parse(Int, statuslinematch.captures[1])
        reasonphrase = statuslinematch.captures[2]
        return HTTPResponse(status, reasonphrase)
    end

    throw(BadHTTPResponse())
end

end