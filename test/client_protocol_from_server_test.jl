using Base.Test
using DandelionWebSockets: OPCODE_PONG, masking!, CLOSE_STATUS_PROTOCOL_ERROR, protocolstate

function textframe_from_server(text::String; final_frame=true)
    Frame(final_frame, OPCODE_TEXT, false, length(text), 0, Vector{UInt8}(), Vector{UInt8}(text))
end

function binaryframe_from_server(data::Vector{UInt8}; final_frame=true)
    Frame(final_frame, OPCODE_BINARY, false, length(data), 0, Vector{UInt8}(), data)
end

function continuation_textframe_from_server(text::String; final_frame=true)
    Frame(final_frame, OPCODE_CONTINUATION, false, length(text), 0, Vector{UInt8}(), Vector{UInt8}(text))
end

function continuation_binaryframe_from_server(data::Vector{UInt8}; final_frame=true)
    Frame(final_frame, OPCODE_CONTINUATION, false, length(data), 0, Vector{UInt8}(), data)
end

function pingframe_from_server(; payload=Vector{UInt8}(), final_frame=true)
    Frame(final_frame, OPCODE_PING, false, 0, 0, Vector{UInt8}(), payload)
end

function pongframe_from_server(; payload=Vector{UInt8}(), final_frame=true)
    Frame(final_frame, OPCODE_PONG, false, 0, 0, Vector{UInt8}(), payload)
end

@testset "Server to client       " begin
    @testset "single frame text message; handler receives message" begin
        # Requirement
        # @6_2-4 Message has been received, single frame

        # Arrange
        logic, handler, writer = makeclientlogic()

        frame = textframe_from_server("Hello")

        # Act
        handle(logic, FrameFromServer(frame))

        # Assert
        @test getsingletext(handler) == "Hello"
    end

    @testset "two single frame text messages; handler receives both messages" begin
        # Arrange
        logic, handler, writer = makeclientlogic()

        frame1 = textframe_from_server("Hello")
        frame2 = textframe_from_server("world")

        # Act
        handle(logic, FrameFromServer(frame1))
        handle(logic, FrameFromServer(frame2))

        # Assert
        @test gettextat(handler, 1) == "Hello"
        @test gettextat(handler, 2) == "world"
    end

    @testset "two messages, both in two frames; handler receives both messages" begin
        # Requirement
        # @6_2-5 Message has been received, multi-frame

        logic, handler, writer = makeclientlogic()

        frame1_1 = textframe_from_server("Hel"; final_frame=false)
        frame1_2 = continuation_textframe_from_server("lo";  final_frame=true)
        frame2_1 = textframe_from_server("wo";  final_frame=false)
        frame2_2 = continuation_textframe_from_server("rld"; final_frame=true)

        handle(logic, FrameFromServer(frame1_1))
        handle(logic, FrameFromServer(frame1_2))
        handle(logic, FrameFromServer(frame2_1))
        handle(logic, FrameFromServer(frame2_2))

        @test gettextat(handler, 1) == "Hello"
        @test gettextat(handler, 2) == "world"
    end

    @testset "a ping request is received between two fragments; pong reply is sent" begin
        # Requirement
        # @5_4-3 Control frames in a fragment sequence
        # @5_4-7 Handling control frames in fragment sequences
        # @5_5_2-2 Pong response
        # @5_5_2-3 Pong response time

        logic, handler, writer = makeclientlogic()

        frame1 = textframe_from_server("Hel"; final_frame=false)
        frame2 = continuation_textframe_from_server("lo";  final_frame=true)
        ping_frame = pingframe_from_server()

        handle(logic, FrameFromServer(frame1))
        handle(logic, FrameFromServer(ping_frame))
        handle(logic, FrameFromServer(frame2))

        written_frame = getframe(writer, 1)
        @test written_frame.opcode == OPCODE_PONG
    end

    @testset "a ping request is received between two fragments; message is still delivered" begin
        # Requirement
        # @5_4-3 Control frames in a fragment sequence
        # @5_4-7 Handling control frames in fragment sequences

        logic, handler, writer = makeclientlogic()

        frame1 = textframe_from_server("Hel"; final_frame=false)
        frame2 = continuation_textframe_from_server("lo";  final_frame=true)
        ping_frame = pingframe_from_server()

        handle(logic, FrameFromServer(frame1))
        handle(logic, FrameFromServer(ping_frame))
        handle(logic, FrameFromServer(frame2))

        @test gettextat(handler, 1) == "Hello"
    end

    @testset "a ping with a payload is received; a pong with the same payload is sent" begin
        # Requirement
        # @5_5_3-1 Pong frame Application data

        mask = b"\x01\x02\x03\x04"
        logic, handler, writer = makeclientlogic(mask=mask)

        ping_frame = pingframe_from_server(payload=b"Some payload")

        handle(logic, FrameFromServer(ping_frame))

        written_frame = getframeunmasked(writer, 1, mask)
        @test written_frame.payload == b"Some payload"
    end

    @testset "a binary single-frame message is received; handler receives message" begin
        # Arrange
        logic, handler, writer = makeclientlogic()

        frame = binaryframe_from_server(b"Hello")

        # Act
        handle(logic, FrameFromServer(frame))

        # Assert
        @test getbinaryat(handler, 1) == b"Hello"
    end

    @testset "two binary fragments are received; full message is delivered" begin
        logic, handler, writer = makeclientlogic()

        frame1 = binaryframe_from_server(b"Hel"; final_frame=false)
        frame2 = continuation_binaryframe_from_server(b"lo";  final_frame=true)

        handle(logic, FrameFromServer(frame1))
        handle(logic, FrameFromServer(frame2))

        @test getbinaryat(handler, 1) == b"Hello"
    end

    @testset "a pong is received from the server; ponger is made aware" begin
        logic, handler, writer, ponger = makeclientlogic()

        pong_frame = pongframe_from_server()

        handle(logic, FrameFromServer(pong_frame))

        @test ponger.no_of_pongs == 1
    end

    @testset "Invalid UTF-8" begin
        @testset "A single-frame message with invalid UTF-8 is received; Connection is failed" begin
            # Requirement
            # @8_1

            logic, handler, writer = makeclientlogic()

            invalidutf8 = b"\xe2"
            invalidframe = Frame(true, OPCODE_TEXT, false, length(invalidutf8), 0, Vector{UInt8}(), invalidutf8)

            handle(logic, FrameFromServer(invalidframe))

            frame = getframe(writer, 1)
            @test frame.opcode == OPCODE_CLOSE
            @test writer.isopen == false
        end

        @testset "A single-frame message with invalid UTF-8 is received; Handler does not receive text" begin
            # Requirement
            # @8_1

            logic, handler, writer = makeclientlogic()

            invalidutf8 = b"\xe2"
            invalidframe = Frame(true, OPCODE_TEXT, false, length(invalidutf8), 0, Vector{UInt8}(), invalidutf8)

            handle(logic, FrameFromServer(invalidframe))

            @test length(handler.texts) == 0
        end

        @testset "A multi-frame message with invalid UTF-8 is received; Connection is failed" begin
            # Requirement
            # @5_6-2 Message has a complete UTF-8 sequence

            logic, handler, writer = makeclientlogic()

            invalidutf8 = b"\xe2"
            frame1 = Frame(false, OPCODE_TEXT, false, length(invalidutf8), 0, Vector{UInt8}(), invalidutf8)
            frame2 = Frame(true, OPCODE_CONTINUATION, false, length(invalidutf8), 0, Vector{UInt8}(), invalidutf8)

            handle(logic, FrameFromServer(frame1))
            handle(logic, FrameFromServer(frame2))

            frame = getframe(writer, 1)
            @test frame.opcode == OPCODE_CLOSE
            @test writer.isopen == false
        end

        @testset "A single-frame message with invalid UTF-8 is received; Handler does not receive text" begin
            logic, handler, writer = makeclientlogic()

            invalidutf8 = b"\xe2"
            frame1 = Frame(false, OPCODE_TEXT, false, length(invalidutf8), 0, Vector{UInt8}(), invalidutf8)
            frame2 = Frame(true, OPCODE_CONTINUATION, false, length(invalidutf8), 0, Vector{UInt8}(), invalidutf8)

            handle(logic, FrameFromServer(frame1))
            handle(logic, FrameFromServer(frame2))

            @test length(handler.texts) == 0
        end
    end

    @testset "Client receives a masked frame from the server" begin
        # Requirement
        # @5_1-5 Client closes connection on masked frame
        # @5_1-6 Client closes connection on masked frame, status code

        @testset "Client receives a masked frame from the server; Client fails the connection" begin
            # Arrange
            logic, handler, writer = makeclientlogic()

            payload = b"Hello"
            frame = Frame(true, OPCODE_TEXT, true, length(payload), 0, b"\x01\x02\x03\x04", payload)

            # Act
            handle(logic, FrameFromServer(frame))

            # Assert
            sentframe = getframe(writer, 1)
            @test sentframe.opcode == OPCODE_CLOSE
            @test writer.isopen == false
        end

        @testset "Client receives a masked frame from the server; Close status is PROTOCOL ERROR" begin
            # Arrange
            mask = b"\x01\x02\x03\x04"
            logic, handler, writer = makeclientlogic(mask=mask)

            payload = b"Hello"
            frame = Frame(true, OPCODE_TEXT, true, length(payload), 0, b"\x01\x02\x03\x04", payload)

            # Act
            handle(logic, FrameFromServer(frame))

            # Assert
            sentframe = getframeunmasked(writer, 1, mask)
            payload = IOBuffer(sentframe.payload)
            @test read(payload, UInt16) == hton(CLOSE_STATUS_PROTOCOL_ERROR.code)
        end

        @testset "Client receives a masked frame from the server; Message is not sent to the handler" begin
            # Arrange
            logic, handler, writer = makeclientlogic()

            payload = b"Hello"
            frame = Frame(true, OPCODE_TEXT, true, length(payload), 0, b"\x01\x02\x03\x04", payload)

            # Act
            handle(logic, FrameFromServer(frame))

            # Assert
            @test length(handler.texts) == 0
        end
    end

    @testset "Client receives a frame with a reserved bit set" begin
        # Requirement
        # @5_2-2 Reserved bits RSV1, RSV2, RSV3, no extension
        @testset "RSV1 bit is set in a frame; Client fails the connection" begin
            # Arrange
            logic, handler, writer = makeclientlogic()

            payload = b"Hello"
            rsv1 = true
            rsv2 = false
            rsv3 = false
            frame = Frame(true, rsv1, rsv2, rsv3, OPCODE_TEXT, false, length(payload), 0, b"", payload)

            # Act
            handle(logic, FrameFromServer(frame))

            # Assert
            sentframe = getframe(writer, 1)
            @test sentframe.opcode == OPCODE_CLOSE
            @test writer.isopen == false
        end

        @testset "RSV1 bit is set in a frame; Message is not sent to handler" begin
            # Arrange
            logic, handler, writer = makeclientlogic()

            payload = b"Hello"
            rsv1 = true
            rsv2 = false
            rsv3 = false
            frame = Frame(true, rsv1, rsv2, rsv3, OPCODE_TEXT, false, length(payload), 0, b"", payload)

            # Act
            handle(logic, FrameFromServer(frame))

            # Assert
            @test length(handler.texts) == 0
        end

        @testset "RSV2 bit is set in a frame; Client fails the connection" begin
            # Arrange
            logic, handler, writer = makeclientlogic()

            payload = b"Hello"
            rsv1 = false
            rsv2 = true
            rsv3 = false
            frame = Frame(true, rsv1, rsv2, rsv3, OPCODE_TEXT, false, length(payload), 0, b"", payload)

            # Act
            handle(logic, FrameFromServer(frame))

            # Assert
            sentframe = getframe(writer, 1)
            @test sentframe.opcode == OPCODE_CLOSE
            @test writer.isopen == false
        end

        @testset "RSV3 bit is set in a frame; Client fails the connection" begin
            # Arrange
            logic, handler, writer = makeclientlogic()

            payload = b"Hello"
            rsv1 = false
            rsv2 = false
            rsv3 = true
            frame = Frame(true, rsv1, rsv2, rsv3, OPCODE_TEXT, false, length(payload), 0, b"", payload)

            # Act
            handle(logic, FrameFromServer(frame))

            # Assert
            sentframe = getframe(writer, 1)
            @test sentframe.opcode == OPCODE_CLOSE
            @test writer.isopen == false
        end
    end

    @testset "Client receives a fragmented control frame" begin
        # Requirement
        # @5_4-4 Control frames are not fragmented

        @testset "Client receives a fragmented CLOSE frame; Client fails the connection" begin
            logic, handler, writer = makeclientlogic()

            # Create a fragmented close frame
            frame = closeframe_from_server(; final_frame=false)
            handle(logic, FrameFromServer(frame))

            @test protocolstate(logic) == STATE_CLOSED
            @test writer.isopen == false
        end

        @testset "Client receives a fragmented PING frame; Client fails the connection" begin
            logic, handler, writer = makeclientlogic()

            # Create a fragmented ping frame
            frame = pingframe_from_server(; final_frame=false)
            handle(logic, FrameFromServer(frame))

            @test protocolstate(logic) == STATE_CLOSED
            @test writer.isopen == false
        end

        @testset "Client receives a fragmented PONG frame; Client fails the connection" begin
            logic, handler, writer = makeclientlogic()

            # Create a fragmented pong frame
            frame = pongframe_from_server(; final_frame=false)
            handle(logic, FrameFromServer(frame))

            @test protocolstate(logic) == STATE_CLOSED
            @test writer.isopen == false
        end
    end

    @testset "Client receives a control frame with too large payload" begin
        # Requirement
        # @5_5-1 Control frame length

        @testset "Client receives a CLOSE frame with payload 126 bytes; Client fails the connection" begin
            logic, handler, writer = makeclientlogic()

            payload = zeros(UInt8, 126)
            frame = closeframe_from_server(; payload=payload)
            handle(logic, FrameFromServer(frame))

            @test protocolstate(logic) == STATE_CLOSED
            @test writer.isopen == false
        end

        @testset "Client receives a CLOSE frame with payload 127 bytes; Client fails the connection" begin
            logic, handler, writer = makeclientlogic()

            payload = zeros(UInt8, 127)
            frame = closeframe_from_server(; payload=payload)
            handle(logic, FrameFromServer(frame))

            @test protocolstate(logic) == STATE_CLOSED
            @test writer.isopen == false
        end

        @testset "Client receives a PING frame with too large payload; Client fails the connection" begin
            logic, handler, writer = makeclientlogic()

            payload = zeros(UInt8, 127)
            frame = pingframe_from_server(; payload=payload)
            handle(logic, FrameFromServer(frame))

            @test protocolstate(logic) == STATE_CLOSED
            @test writer.isopen == false
        end

        @testset "Client receives a PONG frame with too large payload; Client fails the connection" begin
            logic, handler, writer = makeclientlogic()

            payload = zeros(UInt8, 127)
            frame = pongframe_from_server(; payload=payload)
            handle(logic, FrameFromServer(frame))

            @test protocolstate(logic) == STATE_CLOSED
            @test writer.isopen == false
        end
    end
end