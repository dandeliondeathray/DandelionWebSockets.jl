using Base.Test
import DandelionWebSockets: handle
using DandelionWebSockets: AbstractClientLogic, SendTextFrame, FinalFrameAlreadySentException
using DandelionWebSockets: TextFrameSender, sendframe

struct FakeClientLogic <: AbstractClientLogic
    text_frame::Vector{SendTextFrame}

    FakeClientLogic() = new([])
end

handle(f::FakeClientLogic, s::SendTextFrame) = push!(f.text_frame, s)

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
            @test_throws FinalFrameAlreadySentException sendframe(sender, "another frame")

        end
    end
end