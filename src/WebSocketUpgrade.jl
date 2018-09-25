module WebSocketUpgrade

export ResponseParser, dataread, hascompleteresponse

struct ResponseParser end

dataread(::ResponseParser, ::AbstractVector{UInt8}) = nothing
hascompleteresponse(::ResponseParser) = true

end