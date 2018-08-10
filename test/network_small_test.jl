using Test
using DandelionWebSockets: OPCODE_BINARY

mutable struct FakeTLSStream <: IO
    buf::IOBuffer
    write_buf::IOBuffer
    isopen::Bool
    iseof::Bool

    FakeTLSStream() = new(IOBuffer(), IOBuffer(), true, false)
end

test_write(s::FakeTLSStream, frame::Frame) = write(s.buf, frame)
function Base.write(s::FakeTLSStream, frame::Frame)
    mark(s.write_buf)
    write(s.write_buf, frame)
    reset(s.write_buf)
end

Base.write(s::FakeTLSStream, t::UInt8) = write(s.write_buf, t)
Base.write(s::FakeTLSStream, t::UInt16) = write(s.write_buf, t)
Base.write(s::FakeTLSStream, t::UInt64) = write(s.write_buf, t)

Base.read(::FakeTLSStream, ::T) where T = throw(ErrorException())
Base.readavailable(s::FakeTLSStream) = take!(s.buf)
Base.eof(s::FakeTLSStream) = s.iseof

Base.close(s::FakeTLSStream) = s.isopen = false

@testset "TLSBUfferedIO          " begin
    # MbedTLS.SSLContext does not allow you to read bytes from the IO stream. It throws an exception
    # if you try. `BufferedReader` adapts the TLS stream to support byte I/O by reading all
    # available data into a buffer and return data from that.
    @testset "Read two bytes via TLSBufferedIO" begin
        fake_tls = FakeTLSStream()
        write(fake_tls.buf, Vector{UInt8}([1,2]))

        s = DandelionWebSockets.TLSBufferedIO(fake_tls)

        @test read(s, UInt8) == 1
        @test read(s, UInt8) == 2
    end

    @testset "Read frames via TLSBufferedIO" begin
        frame1 = Frame(true, false, false, false, OPCODE_BINARY, false, 126, 256, b"", ones(UInt8, 256))
        frame2 = Frame(true, false, false, false, OPCODE_BINARY, false, 126, 256, b"", zeros(UInt8, 256))
        fake_tls = FakeTLSStream()
        test_write(fake_tls, frame1)
        test_write(fake_tls, frame2)

        s = DandelionWebSockets.TLSBufferedIO(fake_tls)
        @test read(s, Frame) == frame1
        @test read(s, Frame) == frame2
    end

    @testset "Write frames via TLSBufferedIO" begin
        frame1 = Frame(true, false, false, false, OPCODE_BINARY, false, 126, 256, b"", ones(UInt8, 256))
        frame2 = Frame(true, false, false, false, OPCODE_BINARY, false, 126, 256, b"", zeros(UInt8, 256))
        fake_tls = FakeTLSStream()
        s = DandelionWebSockets.TLSBufferedIO(fake_tls)

        mark(fake_tls.write_buf)
        write(s, frame1)
        write(s, frame2)
        reset(fake_tls.write_buf)
        @test read(fake_tls.write_buf, Frame) == frame1
        @test read(fake_tls.write_buf, Frame) == frame2
    end

    @testset "Close a TLSBufferedIO; underlying stream is closed" begin
        fake_tls = FakeTLSStream()
        stream = DandelionWebSockets.TLSBufferedIO(fake_tls)

        close(stream)

        @test fake_tls.isopen == false
    end

    @testset "EOF indicated by eof() method; read throws EOFError" begin
        fake_tls = FakeTLSStream()
        stream = DandelionWebSockets.TLSBufferedIO(fake_tls)
        fake_tls.iseof = true

        @test_throws EOFError read(stream, Frame)
    end
end
