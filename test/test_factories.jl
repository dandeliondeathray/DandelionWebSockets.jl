using DandelionWebSockets

function makeclientlogic(; state=STATE_OPEN,
                           mask=b"\x01\x02\x03\x04",
                           client_cleanup=() -> nothing)
    handler = WebSocketHandlerStub()
    writer = FrameWriterStub()
    mask_generator = FakeRNG{UInt8}(mask)
    ponger = PongerStub()

    logic = ClientLogic(state,
                        handler,
                        writer,
                        mask_generator,
                        ponger,
                        client_cleanup)
    logic, handler, writer, ponger
end
