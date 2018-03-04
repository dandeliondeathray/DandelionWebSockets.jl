using Base.Test
using DandelionWebSockets.Proxy
import DandelionWebSockets.Proxy: write, close

struct MockWriter <: IO
    channel::Channel{Frame}
    closechannel::Channel{Bool}
    exception::Nullable{Exception}

    MockWriter() = new(Channel{Frame}(0), Channel{Bool}(0), Nullable{Exception}())
    MockWriter(ex::Exception) = new(Channel{Frame}(0), Channel{Bool}(0), Nullable{Exception}(ex))
end

function write(m::MockWriter, frame::Frame)
    if isnull(m.exception)
        put!(m.channel, frame)
    else
        throw(get(m.exception))
    end
end

takeframe!(m::MockWriter) = take!(m.channel)
close(m::MockWriter) = put!(m.closechannel, true)
isclosed!(m::MockWriter) = take!(m.closechannel)

@testset "WriterProxy            " begin
    @testset "WriterProxy works in a separate task" begin
        mockwriter = MockWriter()
        proxywriter = WriterProxy(mockwriter)

        frame = Frame(true, 0, 0, 0, OPCODE_TEXT, true, 1, 0, Vector{UInt8}(b"\x01\x02\x03\x04"), b"1")
        write(proxywriter, frame)

        written_frame = takeframe!(mockwriter)
        @test written_frame == frame
    end

    @testset "Stop WriterProxy" begin
        mockwriter = MockWriter()
        proxywriter = WriterProxy(mockwriter)

        stopproxy(proxywriter)

        @test isopen(proxywriter.channel) == false
    end

    @testset "Close the socket via WriterProxy" begin
        mockwriter = MockWriter()
        proxywriter = WriterProxy(mockwriter)

        close(proxywriter)

        @test isclosed!(mockwriter)
    end

    @testset "Streams throws exception on write; Socket is closed" begin
        writer = MockWriter(EOFError())
        proxywriter = WriterProxy(writer)

        frame = Frame(true, 0, 0, 0, OPCODE_TEXT, true, 1, 0, Vector{UInt8}(b"\x01\x02\x03\x04"), b"1")
        write(proxywriter, frame)

        @test isclosed!(writer)
    end
end