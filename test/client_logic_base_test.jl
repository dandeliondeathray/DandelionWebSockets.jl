using Base.Test

using DandelionWebSockets
using DandelionWebSockets: STATE_OPEN, STATE_CONNECTING, STATE_CLOSING, STATE_CLOSED
using DandelionWebSockets: SocketState, AbstractPonger, SendTextFrame, FrameFromServer

function textframe_from_server(text::String; final_frame=true)
    Frame(final_frame, OPCODE_TEXT, false, length(text), 0, Vector{UInt8}(), Vector{UInt8}(text))
end

function continuation_textframe_from_server(text::String; final_frame=true)
    Frame(final_frame, OPCODE_CONTINUATION, false, length(text), 0, Vector{UInt8}(), Vector{UInt8}(text))
end

function pingframe_from_server(; payload=Vector{UInt8}())
    Frame(true, OPCODE_PING, false, 0, 0, Vector{UInt8}(), payload)
end

function makeclientlogic(; state=STATE_OPEN)
    handler = WebSocketHandlerStub()
    writer = FrameWriterStub()
    mask_generator = FakeRNG{UInt8}(b"\x01\x02\x03\x04")
    ponger = PongerStub()
    client_cleanup = () -> nothing

    logic = ClientLogic(state,
                        handler,
                        writer,
                        mask_generator,
                        ponger,
                        client_cleanup)
    logic, handler, writer
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

    @testset "a ping request is received between two fragments; pong is sent" begin
    end

    @testset "a ping request is received between two fragments; message is still delivered" begin
        logic, handler, writer = makeclientlogic()

        frame1_1 = textframe_from_server("Hel"; final_frame=false)
        frame1_2 = continuation_textframe_from_server("lo";  final_frame=true)
        ping_frame = pingframe_from_server()

        handle(logic, FrameFromServer(frame1_1))
        handle(logic, FrameFromServer(ping_frame))
        handle(logic, FrameFromServer(frame1_2))

        @test gettextat(handler, 1) == "Hello"
    end

end