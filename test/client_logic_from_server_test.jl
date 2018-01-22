using Base.Test
using DandelionWebSockets: OPCODE_PONG, masking!

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

function pingframe_from_server(; payload=Vector{UInt8}())
    Frame(true, OPCODE_PING, false, 0, 0, Vector{UInt8}(), payload)
end

function pongframe_from_server(; payload=Vector{UInt8}())
    Frame(true, OPCODE_PONG, false, 0, 0, Vector{UInt8}(), payload)
end

@testset "Server to client" begin
    @testset "single frame text message; handler receives message" begin
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
end