using Base.Test

@testset "Issues                 " begin
    @testset "Issue #12: Masking frames should be done on a copy of data" begin
        # Arrange
        handler = WebSocketHandlerStub()
        writer = FrameWriterStub()
        mask_generator = FakeRNG{UInt8}(b"\x01\x02\x03\x04")
        ponger = PongerStub()
        client_cleanup = () -> nothing

        logic = ClientProtocol(handler,
                            writer,
                            mask_generator,
                            ponger,
                            client_cleanup;
                            state = STATE_OPEN)

        text = "Foo"

        # Act
        handle(logic, SendTextFrame(text, true, OPCODE_TEXT))

        # Assert
        @test text == "Foo"
    end
end