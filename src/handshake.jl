immutable HandshakeResult
    expected_accept::ASCIIString
    stream::IO
    headers::Dict{AbstractString,AbstractString}
    body::Vector{UInt8}
end