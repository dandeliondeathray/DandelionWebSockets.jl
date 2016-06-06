# Core defines the core WebSocket types, such as a frame and opcodes.

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

# TODO: Rethink what we're exporting here. Should we export anything? None of this
#       should be part of the interface to the user.
export Frame,
       Opcode,
       OPCODE_CONTINUATION,
       OPCODE_TEXT,
       OPCODE_BINARY,
       OPCODE_CLOSE,
       OPCODE_PING,
       OPCODE_PONG

import Base.==

# TODO: Documentation.

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

Frame(fin::Bool, opcode::Opcode, ismasked::Bool, len::Int,
      extended_len::Int, mask::Vector{UInt8}, payload::Vector{UInt8}) =
  Frame(fin, false, false, false, opcode, ismasked, len, extended_len, mask, payload)

==(a::Frame, b::Frame) = a.fin == b.fin && a.rsv1 == b.rsv1 && a.rsv2 == b.rsv2 &&
  a.opcode == b.opcode && a.ismasked == b.ismasked && a.len == b.len && a.extended_len == b.extended_len &&
  a.mask == b.mask && a.payload == b.payload

function Base.read(s::IO, ::Type{Frame})
  x    = read(s, UInt8)
  fin  = x & 0b1000_0000 != 0
  rsv1 = x & 0b0100_0000 != 0
  rsv2 = x & 0b0010_0000 != 0
  rsv3 = x & 0b0001_0000 != 0
  op   = x & 0b0000_1111

  y        = read(s, UInt8)
  ismasked = y & 0b1000_0000 != 0
  len      = y & 0b0111_1111

  extended_len::UInt64 = 0
  if len == 126
    extended_len = ntoh(read(s, UInt16))
  elseif len == 127
    extended_len = ntoh(read(s, UInt64))
  end

  mask = Array{UInt8,1}()
  if ismasked
    mask = read(s, UInt8, 4)
  end

  payload_length = extended_len != 0 ? extended_len : len
  payload = read(s, UInt8, payload_length)

  Frame(fin, rsv1, rsv2, rsv3, Opcode(op), ismasked, len, extended_len, mask, payload)
end

function Base.write(s::IO, frame::Frame)
  x1 =
    UInt8(frame.fin)  << 7 |
    UInt8(frame.rsv1) << 6 |
    UInt8(frame.rsv2) << 5 |
    UInt8(frame.rsv3) << 4 |
    frame.opcode.op & 0b0000_1111

  x2 = UInt8(frame.ismasked) << 7 |
       frame.len & 0b0111_1111

  write(s, x1)
  write(s, x2)

  if frame.len == 126
    write(s, hton(UInt16(frame.extended_len)))
  elseif frame.len == 127
    write(s, hton(frame.extended_len))
  end

  if frame.ismasked
    write(s, frame.mask)
  end

  write(s, frame.payload)
end