using Base.Test
using DandelionWebSockets: STATE_OPEN, STATE_CONNECTING, STATE_CLOSING, STATE_CLOSED
using DandelionWebSockets: SocketState, AbstractPonger, SendTextFrame

@testset "Issue #12: Masking frames should be done on a copy of data" begin
    # Arrange
    handler = WebSocketHandlerStub()
    writer = FrameWriterStub()
    mask_generator = FakeRNG{UInt8}(b"\x01\x02\x03\x04")
    ponger = PongerStub()
    client_cleanup = () -> nothing

    logic = ClientLogic(STATE_OPEN,
                        handler,
                        writer,
                        mask_generator,
                        ponger,
                        client_cleanup)

    text = "Foo"

    # Act
    handle(logic, SendTextFrame(text, true, OPCODE_TEXT))

    # Assert
    @test text == "Foo"
end
