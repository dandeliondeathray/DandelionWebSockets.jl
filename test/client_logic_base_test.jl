using Base.Test

using DandelionWebSockets
using DandelionWebSockets: STATE_OPEN, STATE_CONNECTING, STATE_CLOSING, STATE_CLOSED
using DandelionWebSockets: SocketState, AbstractPonger, SendTextFrame, FrameFromServer

function single_textframe_from_server(text::String)
    Frame(true,  OPCODE_TEXT, false, length(text), 0, Vector{UInt8}(), Vector{UInt8}(text))
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

@testset "Receive message" begin
    @testset "single frame text message; handler receives message" begin
        # Arrange
        logic, handler, writer = makeclientlogic()

        frame = single_textframe_from_server("Hello")

        # Act
        handle(logic, FrameFromServer(frame))

        # Assert
        @test getsingletext(handler) == "Hello"
    end

    @testset "two single frame text messages; handler receives both messages" begin
        # Arrange
        logic, handler, writer = makeclientlogic()

        frame1 = single_textframe_from_server("Hello")
        frame2 = single_textframe_from_server("world")

        # Act
        handle(logic, FrameFromServer(frame1))
        handle(logic, FrameFromServer(frame2))

        # Assert
        @test gettextat(handler, 1) == "Hello"
        @test gettextat(handler, 2) == "world"
    end
end