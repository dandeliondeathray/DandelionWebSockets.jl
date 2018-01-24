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

using Base.Test
using BufferedStreams

struct FrameTestCase
    description::AbstractString
    serialized_frame::Array{UInt8}
    frame::Frame
end


@testset "Frame serialization  " begin
    nomask = b""
    mask = b"\x37\xfa\x21\x3d"

    frame_test_cases = [
        FrameTestCase("A single frame unmasked text message, body Hello",
            b"\x81\x05\x48\x65\x6c\x6c\x6f",
            Frame(true, false, false, false, OPCODE_TEXT, false, 5, 0, nomask, b"Hello")),

        FrameTestCase("A single-frame masked text message",
            b"\x81\x85\x37\xfa\x21\x3d\x7f\x9f\x4d\x51\x58",
            Frame(true, false, false, false, OPCODE_TEXT, true, 5, 0, mask, b"\x7f\x9f\x4d\x51\x58")),

        FrameTestCase("Fragmented unmasked text message, first fragment",
            b"\x01\x03\x48\x65\x6c",
            Frame(false, false, false, false, OPCODE_TEXT, false, 3, 0, nomask, b"Hel")),

        FrameTestCase("Fragmented unmasked text message, last fragment",
            b"\x80\x02\x6c\x6f",
            Frame(true, false, false, false, OPCODE_CONTINUATION, false, 2, 0, nomask, b"lo")),

        FrameTestCase("Unmasked ping request",
            b"\x89\x05\x48\x65\x6c\x6c\x6f",
            Frame(true, false, false, false, OPCODE_PING, false, 5, 0, nomask, b"Hello")),

        FrameTestCase("Masked ping response",
            b"\x8a\x85\x37\xfa\x21\x3d\x7f\x9f\x4d\x51\x58",
            Frame(true, false, false, false, OPCODE_PONG, true, 5, 0, mask, b"\x7f\x9f\x4d\x51\x58")),

        FrameTestCase("Binary message, payload is 256 bytes, single unmasked",
            vcat(b"\x82\x7E\x01\x00", zero256),
            Frame(true, false, false, false, OPCODE_BINARY, false, 126, 256, nomask, zeros(UInt8, 256))),

        FrameTestCase("Binary message, payload is 65KiB",
            vcat(b"\x82\x7f\x00\x00\x00\x00\x00\x01\x04\x00", zeros(UInt8, 65536+1024)),
            Frame(true, false, false, false, OPCODE_BINARY, false, 127, 65536 + 1024, nomask, zeros(UInt8, 65536+1024)))
    ]


    for testcase in frame_test_cases
        @testset "$(testcase.description)" begin
            @testset "Read frame from IOBuffer" begin
                s = IOBuffer(testcase.serialized_frame)
                @test read(s, Frame) == testcase.frame
            end

            @testset "Write frame to IOBuffer" begin
                s = IOBuffer()
                write(s, testcase.frame)
                @test take!(s) == testcase.serialized_frame
            end

            @testset "Read frame from BufferedInputStream" begin
                s = IOBuffer(testcase.serialized_frame)
                buffered = BufferedInputStream(s)
                @fact read(buffered, Frame) --> testcase.frame
            end
        end
    end
end
