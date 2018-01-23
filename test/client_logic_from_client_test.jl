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

    @testset "extended payload" begin
        @testset "payload size is 125; payload length is 125, no extended payload" begin
            # Arrange
            logic, handler, writer = makeclientlogic()

            # Act
            payload = zeros(UInt8, 125)
            handle(logic, SendBinaryFrame(payload, true, OPCODE_BINARY))

            # Assert
            frame = getframe(writer, 1)
            @test frame.len == 125
            @test frame.extended_len == 0
        end

        @testset "payload size is 126; payload length is 126, extended payload is 126" begin
            # Arrange
            logic, handler, writer = makeclientlogic()

            # Act
            payload = zeros(UInt8, 126)
            handle(logic, SendBinaryFrame(payload, true, OPCODE_BINARY))

            # Assert
            frame = getframe(writer, 1)
            # When the frames len field says 126, then that means a 16-bit extended length.
            @test frame.len == 126
            @test frame.extended_len == 126
        end


        @testset "payload size is 127; payload length is 126, extended payload is 127" begin
            # Arrange
            logic, handler, writer = makeclientlogic()

            # Act
            payload = zeros(UInt8, 127)
            handle(logic, SendBinaryFrame(payload, true, OPCODE_BINARY))

            # Assert
            frame = getframe(writer, 1)
            # When the frames len field says 126, then that means a 16-bit extended length.
            @test frame.len == 126
            @test frame.extended_len == 127
        end


        @testset "payload size is 128; payload length is 126, extended payload is 128" begin
            # Arrange
            logic, handler, writer = makeclientlogic()

            # Act
            payload = zeros(UInt8, 128)
            handle(logic, SendBinaryFrame(payload, true, OPCODE_BINARY))

            # Assert
            frame = getframe(writer, 1)
            # When the frames len field says 126, then that means a 16-bit extended length.
            @test frame.len == 126
            @test frame.extended_len == 128
        end

        @testset "payload size is 256; extended payload length is 256" begin
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
end