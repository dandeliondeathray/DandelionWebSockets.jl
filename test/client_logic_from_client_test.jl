using Base.Test
using DandelionWebSockets: SendBinaryFrame

@testset "Client to server" begin
    @testset "send single-frame text message; message is sent" begin
        # Arrange
        mask = b"\x01\x02\x03\x04"
        logic, handler, writer = makeclientlogic(mask=mask)

        # Act
        handle(logic, SendTextFrame("Hello", true, OPCODE_TEXT))

        # Assert
        frame = getframeunmasked(writer, 1, mask)
        @test frame.payload == b"Hello"
        @test frame.fin == true
        @test frame.opcode == OPCODE_TEXT
    end

    @testset "send single-frame binary message; message is sent" begin
        # Arrange
        mask = b"\x01\x02\x03\x04"
        logic, handler, writer = makeclientlogic(mask=mask)

        # Act
        handle(logic, SendBinaryFrame(b"Hello", true, OPCODE_BINARY))

        # Assert
        frame = getframeunmasked(writer, 1, mask)
        @test frame.payload == b"Hello"
        @test frame.fin == true
        @test frame.opcode == OPCODE_BINARY
    end

    @testset "send binary message with 256 byte payload; extended payload length is 256" begin
        # Arrange
        logic, handler, writer = makeclientlogic()

        # Act
        payload = zeros(UInt8, 256)
        handle(logic, SendBinaryFrame(payload, true, OPCODE_BINARY))

        # Assert
        frame = getframe(writer, 1)
        @test frame.len == 126
        @test frame.extended_len == 256
    end

    @testset "send binary message with 256 byte payload; extended payload length is 256" begin
        # Arrange
        logic, handler, writer = makeclientlogic()

        # Act
        payload = zeros(UInt8, 256)
        handle(logic, SendBinaryFrame(payload, true, OPCODE_BINARY))

        # Assert
        frame = getframe(writer, 1)
        @test frame.len == 126
        @test frame.extended_len == 256
    end

end