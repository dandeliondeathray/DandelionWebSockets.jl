immutable HandshakeResult
    expected_accept::ASCIIString
    stream::IO
    headers::Dict{ASCIIString,ASCIIString}
    body::Vector{UInt8}
end

function validate(handshake::HandshakeResult)
    accept_name = "Sec-WebSocket-Accept"
    if !haskey(handshake.headers, accept_name)
        return false
    end

    accept_value = handshake.headers[accept_name]
    return accept_value == handshake.expected_accept
end