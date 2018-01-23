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

        @testset "payload size 65535 (0xFFFF); extended payload length is 65536" begin
            # This is the max payload size representable by the 16-bit extended length,
            # where len is 126.
            # Arrange
            logic, handler, writer = makeclientlogic()

            # Act
            payload = zeros(UInt8, 65535)
            handle(logic, SendBinaryFrame(payload, true, OPCODE_BINARY))

            # Assert
            frame = getframe(writer, 1)
            @test frame.len == 126
            @test frame.extended_len == 65535
        end

        @testset "payload size is 65536; len is 127 and extended length is 65536" begin
            # This is one byte more than the max payload size representable by the 16-bit extended
            # length, and then len is 127 and the 64-bit extended length is used.
            # Arrange
            logic, handler, writer = makeclientlogic()

            # Act
            payload = zeros(UInt8, 65536)
            handle(logic, SendBinaryFrame(payload, true, OPCODE_BINARY))

            # Assert
            frame = getframe(writer, 1)
            @test frame.len == 127
            @test frame.extended_len == 65536
        end
    end

    @testset "send a message in two fragments; two fragments are written" begin
        mask1 = b"\x01\x02\x03\x04"
        mask2 = b"\x05\x06\x07\x08"
        logic, handler, writer = makeclientlogic(mask=[mask1; mask2])

        handle(logic, SendTextFrame("Hel", false, OPCODE_TEXT))
        handle(logic, SendTextFrame("lo", true, OPCODE_TEXT))

        frame1 = getframeunmasked(writer, 1, mask1)
        @test frame1.opcode == OPCODE_TEXT
        @test frame1.payload == b"Hel"
        @test frame1.fin == false

        frame2 = getframeunmasked(writer, 2, mask2)
        @test frame2.opcode == OPCODE_TEXT
        @test frame2.payload == b"lo"
        @test frame2.fin == true
    end

    @testset "connection is in CLOSING, requesting to send a message; no message is sent" begin
        logic, handler, writer = makeclientlogic(state=STATE_CLOSING)

        handle(logic, SendTextFrame("Hello", true, OPCODE_TEXT))

        @test get_no_of_frames_written(writer) == 0
    end
end