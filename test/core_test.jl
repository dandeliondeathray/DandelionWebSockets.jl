# From https://tools.ietf.org/html/rfc6455, chapter 5.7.
#
# 5.7.  Examples
#
#    o  A single-frame unmasked text message
#
#       *  0x81 0x05 0x48 0x65 0x6c 0x6c 0x6f (contains "Hello")
#
#    o  A single-frame masked text message
#
#       *  0x81 0x85 0x37 0xfa 0x21 0x3d 0x7f 0x9f 0x4d 0x51 0x58
#          (contains "Hello")
#
#    o  A fragmented unmasked text message
#
#       *  0x01 0x03 0x48 0x65 0x6c (contains "Hel")
#
#       *  0x80 0x02 0x6c 0x6f (contains "lo")
#
#    o  Unmasked Ping request and masked Ping response
#
#       *  0x89 0x05 0x48 0x65 0x6c 0x6c 0x6f (contains a body of "Hello",
#          but the contents of the body are arbitrary)
#
#       *  0x8a 0x85 0x37 0xfa 0x21 0x3d 0x7f 0x9f 0x4d 0x51 0x58
#          (contains a body of "Hello", matching the body of the ping)
#
#    o  256 bytes binary message in a single unmasked frame
#
#       *  0x82 0x7E 0x0100 [256 bytes of binary data]
#
#    o  64KiB binary message in a single unmasked frame
#
#      *  0x82 0x7F 0x0000000000010000 [65536 bytes of binary data]
#

immutable FrameTestCase
    description::AbstractString
    input::Array{UInt8}
    expected::Frame
end

frame_test_cases = [
    FrameTestCase("A single frame unmasked text message, body Hello",
        b"\x81\x05\x48\x65\x6c\x6c\x6f",
        Frame(true, false, false, false, OPCODE_TEXT, false, 5, 0, Array{UInt8}(), b"Hello")),
    FrameTestCase("A single-frame masked text message",
        b"\x81\x85\x37\xfa\x21\x3d\x7f\x9f\x4d\x51\x58",
        Frame(true, false, false, false, OPCODE_TEXT, true, 5, 0, b"\x37\xfa\x21\x3d", b"Hello"))
]

facts("Reading frames") do
    for tc in frame_test_cases
        context(tc.description) do
            s = IOBuffer(tc.input)
            @fact read(s, Frame) --> tc.expected
        end
    end
end
