using DandelionWebSockets
using DandelionWebSockets: FrameWriter

function makeclientlogic(; state=STATE_OPEN,
                           mask=b"\x01\x02\x03\x04",
                           client_cleanup=() -> nothing)
    handler = WebSocketHandlerStub()
    writer = FrameIOStub()
    mask_generator = FakeRNG{UInt8}(mask)
    ponger = PongerStub()
    framewriter = FrameWriter(writer, mask_generator)

    logic = ClientProtocol(handler,
                        framewriter,
                        ponger,
                        client_cleanup;
                        state = state)
    logic, handler, writer, ponger
end
