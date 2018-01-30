using DandelionWebSockets

function makeclientlogic(; state=STATE_OPEN,
                           mask=b"\x01\x02\x03\x04",
                           client_cleanup=() -> nothing)
    handler = WebSocketHandlerStub()
    writer = FrameWriterStub()
    mask_generator = FakeRNG{UInt8}(mask)
    ponger = PongerStub()

    logic = ClientLogic(handler,
                        writer,
                        mask_generator,
                        ponger,
                        client_cleanup;
                        state = state)
    logic, handler, writer, ponger
end
