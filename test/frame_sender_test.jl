using Base.Test
import DandelionWebSockets: handle
using DandelionWebSockets: AbstractClientProtocol, SendTextFrame, FinalFrameAlreadySentException
using DandelionWebSockets: TextFrameSender, sendframe, BinaryFrameSender

struct FakeClientProtocol <: AbstractClientProtocol
    text_frame::Vector{SendTextFrame}
    binary_frame::Vector{SendBinaryFrame}

    FakeClientProtocol() = new([], [])
end

handle(f::FakeClientProtocol, s::SendTextFrame) = push!(f.text_frame, s)
handle(f::FakeClientProtocol, b::SendBinaryFrame) = push!(f.binary_frame, b)

@testset "Multi-frame message    " begin
    # These are tests for sending multi-frame message.
    #
    # Requirement
    # @5_4-2 Fragmented messages
    # @5_4-5 Fragment order
    # @5_4-8 Fragment size for non control messages
    # @5_4-9 Fragmented and unfragmented messages.
    # @6_1-4 Encapsulating data in multi-frame messages.
    # @6_1-6 FIN bit must be set in the last frame.
    # @6_1-8 Transmitting frames.
    #
    # These tests collectively test requirement @5_4-2.
    #
    # Fragments are sent in the order in which the user requests they are sent, by design.
    # The receiving part of fragmentation order is also done by design in client_logic.jl.
    #
    # Fragment size is not constrained in any way. The payload is taken as is by the client.
    @testset "Text frames" begin
        @testset "First frame; Opcode is OPCODE_TEXT" begin
            # Arrange
            logic = FakeClientProtocol()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "Hello")

            # Assert
            @test logic.text_frame[1].opcode == OPCODE_TEXT
        end

        @testset "Second frame; Opcode is OPCODE_CONTINUATION" begin
            # Arrange
            logic = FakeClientProtocol()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "Hello")
            sendframe(sender, "world")

            # Assert
            @test logic.text_frame[2].opcode == OPCODE_CONTINUATION
        end

        @testset "First frame; frame isn't the final" begin
            # Arrange
            logic = FakeClientProtocol()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "Hello")

            # Assert
            @test logic.text_frame[1].isfinal == false
        end

        @testset "Second frame that isn't last; frame isn't final" begin
            # Arrange
            logic = FakeClientProtocol()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "Hello")
            sendframe(sender, "world")

            # Assert
            @test logic.text_frame[2].isfinal == false
        end

        @testset "Last frame; frame is final" begin
            # Arrange
            logic = FakeClientProtocol()
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
            logic = FakeClientProtocol()
            sender = TextFrameSender(logic)

            # Act
            sendframe(sender, "lastframe"; isfinal=true)

            # Assert
            @test_throws FinalFrameAlreadySentException sendframe(sender, "another frame")
        end

        @testset "User can send invalid UTF-8 as a byte vector; Frame is sent" begin
            logic = FakeClientProtocol()
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
            logic = FakeClientProtocol()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"Hello")

            # Assert
            @test logic.binary_frame[1].opcode == OPCODE_BINARY
        end

        @testset "Second frame; Opcode is OPCODE_CONTINUATION" begin
            # Arrange
            logic = FakeClientProtocol()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"Hello")
            sendframe(sender, b"world")

            # Assert
            @test logic.binary_frame[2].opcode == OPCODE_CONTINUATION
        end

        @testset "First frame; frame isn't the final" begin
            # Arrange
            logic = FakeClientProtocol()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"Hello")

            # Assert
            @test logic.binary_frame[1].isfinal == false
        end

        @testset "Second frame that isn't last; frame isn't final" begin
            # Arrange
            logic = FakeClientProtocol()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"Hello")
            sendframe(sender, b"world")

            # Assert
            @test logic.binary_frame[2].isfinal == false
        end

        @testset "Last frame; frame is final" begin
            # Arrange
            logic = FakeClientProtocol()
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
            logic = FakeClientProtocol()
            sender = BinaryFrameSender(logic)

            # Act
            sendframe(sender, b"lastframe"; isfinal=true)

            # Assert
            @test_throws FinalFrameAlreadySentException sendframe(sender, b"another frame")
        end

    end
end