using Base.Test
using DandelionWebSockets.Proxy
import DandelionWebSockets.Proxy: write

struct MockWriter <: IO
    channel::Channel{Frame}

    MockWriter() = new(Channel{Frame}(0))
end

write(m::MockWriter, frame::Frame) = put!(m.channel, frame)
takeframe!(m::MockWriter) = take!(m.channel)

@testset "WriterProxy          " begin
    @testset "WriterProxy works in a separate task" begin
        mockwriter = MockWriter()
        proxywriter = WriterProxy(mockwriter)

        frame = Frame(true, 0, 0, 0, OPCODE_TEXT, true, 1, 0, Vector{UInt8}(b"\x01\x02\x03\x04"), b"1")
        write(proxywriter, frame)

        written_frame = takeframe!(mockwriter)
        @test written_frame == frame
    end
end