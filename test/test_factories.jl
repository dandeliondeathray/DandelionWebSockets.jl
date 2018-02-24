using DandelionWebSockets
using DandelionWebSockets: FrameWriter, Frame, OPCODE_CLOSE, CloseStatus

function makeclientlogic(; mask=b"\x01\x02\x03\x04",
                           client_cleanup=() -> nothing)
    handler = WebSocketHandlerStub()
    writer = FrameIOStub()
    mask_generator = FakeRNG{UInt8}(mask)
    ponger = PongerStub()
    framewriter = FrameWriter(writer, mask_generator)

    logic = ClientProtocol(handler,
                        framewriter,
                        ponger,
                        client_cleanup)
    logic, handler, writer, ponger
end

function closeframe_from_server(; payload::Vector{UInt8} = b"", final_frame=true)
    Frame(final_frame, OPCODE_CLOSE, false, length(payload), 0, Vector{UInt8}(), payload)
end

function closeframepayload(status::CloseStatus; reason = "")
    payload = IOBuffer()

    write(payload, hton(status.code))
    if reason != ""
        write(payload, Vector{UInt8}(reason))
    end

    take!(payload)
end

function servercloseframe(status::CloseStatus; reason = "")
    payload = closeframepayload(status; reason=reason)
    return closeframe_from_server(; payload=payload)
end