using Test
using DandelionWebSockets: masking!

@testset "Masking                " begin
    mask = b"\x37\xfa\x21\x3d"
    masking_test_examples = [
        # The first element in each tuple is the input, and the second element
        # is the expected masked output, when using the mask defined here.
        (b"Hello", b"\x7f\x9f\x4d\x51\x58"),
        (b"Hel",   b"\x7f\x9f\x4d"),
    ]

    @testset "Masking a payload" begin
        # Requirement
        # @5_3-3 Mask operation

        for example in masking_test_examples
            masked_input = copy(example[1])
            masking!(masked_input, mask)
            @test masked_input == example[2]
        end
    end

    @testset "Masking is its own inverse" begin
        # Requirement
        # @5_3-3 Mask operation

        for example in masking_test_examples
            masked_input = copy(example[2])
            masking!(masked_input, mask)
            @test masked_input == example[1]
        end
    end

    @testset "The mask bit is set for masked frames" begin
        # Requirement
        # @5_3-1

        frame = Frame(true, false, false, false, OPCODE_TEXT, true, 5, 0, b"\x01\x02\x03\x04", b"\x7f\x9f\x4d\x51\x58")
        s = IOBuffer()

        # Mark the beginning of the buffer...
        mark(s)
        write(s, frame)

        # ... so that we can reset it and read it all back
        reset(s)
        readframe = read(s, Frame)
        @test readframe.ismasked
    end
end
