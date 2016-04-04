# Description of a WebSocket frame from https://tools.ietf.org/html/rfc6455, chapter 5.2.
#
#      0                   1                   2                   3
#      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
#     +-+-+-+-+-------+-+-------------+-------------------------------+
#     |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
#     |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
#     |N|V|V|V|       |S|             |   (if payload len==126/127)   |
#     | |1|2|3|       |K|             |                               |
#     +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
#     |     Extended payload length continued, if payload len == 127  |
#     + - - - - - - - - - - - - - - - +-------------------------------+
#     |                               |Masking-key, if MASK set to 1  |
#     +-------------------------------+-------------------------------+
#     | Masking-key (continued)       |          Payload Data         |
#     +-------------------------------- - - - - - - - - - - - - - - - +
#     :                     Payload Data continued ...                :
#     + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
#     |                     Payload Data continued ...                |
#     +---------------------------------------------------------------+

export Frame,
       Opcode,
       OPCODE_CONTINUATION,
       OPCODE_TEXT,
       OPCODE_BINARY,
       OPCODE_CLOSE,
       OPCODE_PING,
       OPCODE_PONG

import Base.==

immutable Opcode
    op::UInt8
end

const OPCODE_CONTINUATION = Opcode(0)
const OPCODE_TEXT         = Opcode(1)
const OPCODE_BINARY       = Opcode(2)
const OPCODE_CLOSE        = Opcode(8)
const OPCODE_PING         = Opcode(9)
const OPCODE_PONG         = Opcode(10)

==(a::Opcode, b::Opcode) = a.op == b.op

immutable Frame
    fin::Bool
    rsv1::Bool
    rsv2::Bool
    rsv3::Bool
    opcode::Opcode
    ismasked::Bool
    len::UInt8 # Is actually 7 bits.
    extended_len::UInt64
    mask::Array{UInt8}
    payload::Array{UInt8}
end

Base.read(s::IO, ::Type{Frame}) = nothing
