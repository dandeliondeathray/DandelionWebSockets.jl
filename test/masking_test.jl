using Base.Test
using DandelionWebSockets: masking!

@testset "Masking              " begin
    mask = b"\x37\xfa\x21\x3d"
    masking_test_examples = [
        # The first element in each tuple is the input, and the second element
        # is the expected masked output, when using the mask defined here.
        (b"Hello", b"\x7f\x9f\x4d\x51\x58"),
        (b"Hel",   b"\x7f\x9f\x4d"),
    ]

    @testset "Masking a payload" begin
        for example in masking_test_examples
            masked_input = copy(example[1])
            masking!(masked_input, mask)
            @test masked_input == example[2]
        end
    end

    @testset "Masking is its own inverse" begin
        for example in masking_test_examples
            masked_input = copy(example[2])
            masking!(masked_input, mask)
            @test masked_input == example[1]
        end
    end
end
