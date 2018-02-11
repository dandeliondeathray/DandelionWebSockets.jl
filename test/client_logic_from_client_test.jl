using Base.Test
using DandelionWebSockets: SendBinaryFrame, ClientPingRequest

@testset "Client to server       " begin
    @testset "Send single-frame text message; message is sent" begin
        # Requirement
        # @5_1-1 Client masks frame

        # Arrange
        mask = b"\x01\x02\x03\x04"
        logic, handler, writer = makeclientlogic(mask=mask)

        # Act
        handle(logic, SendTextFrame("Hello", true, OPCODE_TEXT))

        # Assert
        frame = getframeunmasked(writer, 1, mask)
        @test frame.payload == b"Hello"
        @test frame.opcode == OPCODE_TEXT
    end

    @testset "Send single-frame text message; FIN bit is set on first frame" begin
        # Requirement
        # @5_2-1 FIN bit is set on the first frame

        # Arrange
        mask = b"\x01\x02\x03\x04"
        logic, handler, writer = makeclientlogic(mask=mask)

        # Act
        handle(logic, SendTextFrame("Hello", true, OPCODE_TEXT))

        # Assert
        frame = getframeunmasked(writer, 1, mask)
        @test frame.fin == true
    end

    @testset "Send single-frame binary message; message is sent" begin
        # Requirement
        # @5_1-1 Client masks frame

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
            # Requirement
            # @5_2-6 Payload length, 0-125 bytes

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
            # Requirement
            # @5_2-7 Payload length, 126 bytes

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
            # Requirement
            # @5_2-8 Payload length, 127 bytes

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
            # Requirement
            # @5_2-9 Minimal encoding of payload length

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
            # Requirement
            # @5_2-9 Minimal encoding of payload length

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
            # Requirement
            # @5_2-9 Minimal encoding of payload length

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
            # Requirement
            # @5_2-9 Minimal encoding of payload length

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

    @testset "connection is in CLOSING, trying to send a message; no message is sent" begin
        logic, handler, writer = makeclientlogic(state=STATE_CLOSING)

        handle(logic, SendTextFrame("Hello", true, OPCODE_TEXT))

        @test get_no_of_frames_written(writer) == 0
    end

    @testset "connection is in CONNECTING, trying to send a message; no message is sent" begin
        logic, handler, writer = makeclientlogic(state=STATE_CONNECTING)

        handle(logic, SendTextFrame("Hello", true, OPCODE_TEXT))

        @test get_no_of_frames_written(writer) == 0
    end

    @testset "connection is in CLOSED, trying to send a message; no message is sent" begin
        logic, handler, writer = makeclientlogic(state=STATE_CLOSED)

        handle(logic, SendTextFrame("Hello", true, OPCODE_TEXT))

        @test get_no_of_frames_written(writer) == 0
    end

    @testset "sending a ping to the server; Ponger is made aware that a ping was sent" begin
        logic, handler, writer, ponger = makeclientlogic()

        handle(logic, ClientPingRequest())

        @test ponger.no_of_pings_sent == 1
    end

    @testset "sending a ping to the server; a ping frame is sent" begin
        logic, handler, writer = makeclientlogic()

        handle(logic, ClientPingRequest())

        frame = getframe(writer, 1)
        @test frame.opcode == OPCODE_PING
    end

    @testset "pings are not sent in non-open states" begin
        @testset "state is CONNECTING; no ping is sent" begin
            logic, handler, writer, ponger = makeclientlogic(state=STATE_CONNECTING)

            handle(logic, ClientPingRequest())

            @test ponger.no_of_pings_sent == 0
            @test get_no_of_frames_written(writer) == 0
        end

        @testset "state is CLOSING; no ping is sent" begin
            logic, handler, writer, ponger = makeclientlogic(state=STATE_CLOSING)

            handle(logic, ClientPingRequest())

            @test ponger.no_of_pings_sent == 0
            @test get_no_of_frames_written(writer) == 0
        end

        @testset "state is CLOSED; no ping is sent" begin
            logic, handler, writer, ponger = makeclientlogic(state=STATE_CLOSED)

            handle(logic, ClientPingRequest())

            @test ponger.no_of_pings_sent == 0
            @test get_no_of_frames_written(writer) == 0
        end
    end
end