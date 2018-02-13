using Base.Test
import DandelionWebSockets: handle
using DandelionWebSockets: AbstractClientLogic, SendTextFrame, FinalFrameAlreadySentException
using DandelionWebSockets: TextFrameSender, sendframe, BinaryFrameSender

struct FakeClientLogic <: AbstractClientLogic
    text_frame::Vector{SendTextFrame}
    binary_frame::Vector{SendBinaryFrame}

    FakeClientLogic() = new([], [])
end

handle(f::FakeClientLogic, s::SendTextFrame) = push!(f.text_frame, s)
handle(f::FakeClientLogic, b::SendBinaryFrame) = push!(f.binary_frame, b)

@testset "Multi-frame message    " begin
    # These are tests for sending multi-frame message.
    @testset "Text frames" begin
        @testset "First frame; Opcode is OPCODE_TEXT" begin
            # Arrange
            logic = FakeClientLogic()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "Hello")

            # Assert
            @test logic.text_frame[1].opcode == OPCODE_TEXT
        end

        @testset "Second frame; Opcode is OPCODE_CONTINUATION" begin
            # Arrange
            logic = FakeClientLogic()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "Hello")
            sendframe(sender, "world")

            # Assert
            @test logic.text_frame[2].opcode == OPCODE_CONTINUATION
        end

        @testset "First frame; frame isn't the final" begin
            # Arrange
            logic = FakeClientLogic()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "Hello")

            # Assert
            @test logic.text_frame[1].isfinal == false
        end

        @testset "Second frame that isn't last; frame isn't final" begin
            # Arrange
            logic = FakeClientLogic()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "Hello")
            sendframe(sender, "world")

            # Assert
            @test logic.text_frame[2].isfinal == false
        end

        @testset "Last frame; frame is final" begin
            # Arrange
            logic = FakeClientLogic()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "Hello")
            sendframe(sender, "world")
            sendframe(sender, "lastframe"; isfinal=true)

            # Assert
            @test logic.text_frame[3].isfinal == true
        end

        @testset "Send frame after the final; Exception is thrown" begin
            # Arrange
            logic = FakeClientLogic()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "lastframe"; isfinal=true)

            # Assert
            @test_throws FinalFrameAlreadySentException sendframe(sender, "another frame")
        end

        @testset "User can send invalid UTF-8 as a byte vector; Frame is sent" begin
            logic = FakeClientLogic()
            sender = TextFrameSender(logic)

            text = "\u2000"
            # The first byte of the above UTF-8 is invalid as a UTF-8 string.
            text_as_binary = Vector{UInt8}(text)
            payload = text_as_binary[1:1]

            sendframe(sender, payload)

            @test logic.text_frame[1].data == payload
        end
    end

    @testset "Binary frames" begin
        @testset "First frame; Opcode is OPCODE_TEXT" begin
            # Arrange
            logic = FakeClientLogic()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"Hello")

            # Assert
            @test logic.binary_frame[1].opcode == OPCODE_BINARY
        end

        @testset "Second frame; Opcode is OPCODE_CONTINUATION" begin
            # Arrange
            logic = FakeClientLogic()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"Hello")
            sendframe(sender, b"world")

            # Assert
            @test logic.binary_frame[2].opcode == OPCODE_CONTINUATION
        end

        @testset "First frame; frame isn't the final" begin
            # Arrange
            logic = FakeClientLogic()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"Hello")

            # Assert
            @test logic.binary_frame[1].isfinal == false
        end

        @testset "Second frame that isn't last; frame isn't final" begin
            # Arrange
            logic = FakeClientLogic()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"Hello")
            sendframe(sender, b"world")

            # Assert
            @test logic.binary_frame[2].isfinal == false
        end

        @testset "Last frame; frame is final" begin
            # Arrange
            logic = FakeClientLogic()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"Hello")
            sendframe(sender, b"world")
            sendframe(sender, b"lastframe"; isfinal=true)

            # Assert
            @test logic.binary_frame[3].isfinal == true
        end

        @testset "Send frame after the final; Exception is thrown" begin
            # Arrange
            logic = FakeClientLogic()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"lastframe"; isfinal=true)

            # Assert
            @test_throws FinalFrameAlreadySentException sendframe(sender, b"another frame")
        end

    end
end