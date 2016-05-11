import Base: read, write, readavailable
import WebSocketClient: start, stop, WriterTaskProxy, FrameFromServer, SocketClosed

# To accurately test a fake TCPSocket I need a blocking stream.
# The implementation below is meant to be simple, not performant or good.
type BlockingStream <: IO
    buf::IOBuffer
end

function blocking_read(s::BlockingStream)
    x = nothing
    while true
        try
            x = read(s.buf, UInt8)
            return x
        catch ex
            if !isa(ex, EOFError)
                rethrow(ex)
            end
        end
        sleep(0.05)
    end
    x
end

function Base.read(s::BlockingStream, ::Type{UInt8})
    blocking_read(s)
end

function Base.read(s::BlockingStream, ::Type{Array{UInt8, 1}}, n::Int)
    buf = Array{UInt8, 1}(n)
    for i in 1:n
        buf[i] = blocking_read(s)
    end
    buf
end

function Base.read(s::BlockingStream, ::Type{UInt64})
    buf = read(s, Array{UInt8, 1}, 8)
    x::UInt64 =
        buf[1] << 56 | buf[2] << 48 << buf[3] << 40 | buf[4] << 32 |
        buf[5] << 24 | buf[6] << 16 << buf[7] << 8  | buf[8]
    x
end

function Base.read(s::BlockingStream, ::Type{UInt16})
    buf = read(s, Array{UInt8, 1}, 2)
    x::UInt16 = buf[1] << 8 | buf[2]
    x
end


test_frame1 = Frame(true, false, false, false, OPCODE_TEXT, false, 5, 0, nomask, b"Hello")
test_frame2 = Frame(false, false, false, false, OPCODE_TEXT, false, 3, 0, nomask, b"Hel")
test_frame3 = Frame(true, false, false, false, OPCODE_CONTINUATION, false, 2, 0, nomask, b"lo")
network_test_frame4 =
    Frame(true, false, false, false, OPCODE_BINARY, false, 126, 256, nomask, zero256)

facts("Reader task") do
    context("Start and stop") do
        # Start async reader task
        # Check that it's running.
        s = BlockingStream(IOBuffer())
        logic = MockClientTaskProxy([
            (symbol("WebSocketClient.handle"), [SocketClosed()])
        ])

        reader = WebSocketClient.start_reader(s, logic)
        sleep(0.1)
        @fact reader.task --> istaskstarted
        @fact reader.task --> not(istaskdone)

        # Stop reader task
        # Check that it isn't running.
        WebSocketClient.stop_reader(reader)
        sleep(0.1)
        @fact istaskdone(reader.task) --> true

        check_mock(logic)
    end

    context("Start and stop2") do
        framebuf = IOBuffer(Array{UInt8, 1}(), true, true)
        write(framebuf, test_frame1)
        iobuf = IOBuffer(takebuf_array(framebuf))
        s = BlockingStream(iobuf)
        logic = MockClientTaskProxy([
            (symbol("WebSocketClient.handle"), [SocketClosed()])
        ])

        reader = WebSocketClient.start_reader(s, logic)
        sleep(0.1)
        @fact reader.task --> istaskstarted
        @fact reader.task --> not(istaskdone)

        # Stop reader task
        # Check that it isn't running.
        WebSocketClient.stop_reader(reader)
        sleep(0.1)
        @fact istaskdone(reader.task) --> true

        check_mock(logic)
    end

#    context("Read a frame and stop") do
#        framebuf = IOBuffer(Array{UInt8, 1}(), true, true)
#        write(framebuf, test_frame1)
#        iobuf = IOBuffer(takebuf_array(framebuf))
#        s = BlockingStream(iobuf)
#
#        logic = MockClientTaskProxy([
#            (symbol("WebSocketClient.handle"), [FrameFromServer(test_frame1)]),
#            (symbol("WebSocketClient.handle"), [SocketClosed()])
#        ])
#
#        @sync begin
#            @async begin
#                reader = WebSocketClient.start_reader(s, logic)
#                sleep(0.1)
#                WebSocketClient.stop_reader(reader)
#                sleep(0.2)
#                @fact reader.task --> istaskdone
#            end
#        end
#    end
#
#    context("Read several frames and stop") do
#        framebuf = IOBuffer(Array{UInt8, 1}(), true, true)
#        write(framebuf, test_frame1)
#        write(framebuf, test_frame2)
#        write(framebuf, test_frame3)
#        iobuf = IOBuffer(takebuf_array(framebuf))
#        s = BlockingStream(iobuf)
#
#        logic = MockClientTaskProxy([
#            (symbol("WebSocketClient.handle"), [FrameFromServer(test_frame1)]),
#            (symbol("WebSocketClient.handle"), [FrameFromServer(test_frame2)]),
#            (symbol("WebSocketClient.handle"), [FrameFromServer(test_frame3)]),
#            (symbol("WebSocketClient.handle"), [SocketClosed()])
#        ])
#
#        reader = WebSocketClient.start_reader(s, logic)
#        sleep(0.1)
#        WebSocketClient.stop_reader(reader)
#        sleep(0.1)
#        @fact reader.task --> istaskdone
#    end
end


type MockFrameStream <: IO
    frames::Vector{Frame}
end

Base.write(s::MockFrameStream, frame::Frame) = push!(s.frames, frame)

function expect(s::MockFrameStream, frame::Frame)
    @fact s.frames --> x -> !isempty(x)

    actual = shift!(s.frames)
    @fact actual --> frame
end

facts("Writer task") do
    context("Stop and start writer") do
        s = MockFrameStream(Vector{Frame}())
        writer = WriterTaskProxy(s)
        task = start(writer)
        sleep(0.05)
        @fact task --> not(istaskdone)

        stop(writer)
        sleep(0.05)
        @fact task --> istaskdone
    end

    context("Write a few frames") do
        s = MockFrameStream(Vector{Frame}())

        writer = WriterTaskProxy(s)
        task = start(writer)
        sleep(0.05)
        @fact task --> not(istaskdone)

        write(writer, test_frame1)
        write(writer, test_frame2)
        write(writer, test_frame3)

        sleep(0.1)

        expect(s, test_frame1)
        expect(s, test_frame2)
        expect(s, test_frame3)

        stop(writer)
        sleep(0.1)
        @fact task --> istaskdone
    end
end

type FakeTLSStream <: IO
    buf::IOBuffer
    write_buf::IOBuffer

    FakeTLSStream() = new(IOBuffer(), IOBuffer())
end

test_write(s::FakeTLSStream, frame::Frame) = write(s.buf, frame)
function write(s::FakeTLSStream, frame::Frame)
    mark(s.write_buf)
    write(s.write_buf, frame)
    reset(s.write_buf)
end

write(s::FakeTLSStream, t::UInt8) = write(s.write_buf, t)
write(s::FakeTLSStream, t::UInt16) = write(s.write_buf, t)
write(s::FakeTLSStream, t::UInt64) = write(s.write_buf, t)


read{T}(::FakeTLSStream, ::T) = throw(ErrorException())
readavailable(s::FakeTLSStream) = takebuf_array(s.buf)

facts("Byte stream from SSL socket") do
    # MbedTLS.SSLContext does not allow you to read bytes from the IO stream. It throws an exception
    # if you try. `BufferedReader` adapts the TLS stream to support byte I/O by reading all
    # available data into a buffer and return data from that.
    context("Read two bytes via TLSBufferedIO") do
        fake_tls = FakeTLSStream()
        write(fake_tls.buf, Vector{UInt8}([1,2]))

        s = WebSocketClient.TLSBufferedIO(fake_tls)

        @fact read(s, UInt8) --> 1
        @fact read(s, UInt8) --> 2
    end

    context("Read frames via TLSBufferedIO") do
        fake_tls = FakeTLSStream()
        test_write(fake_tls, test_frame1)
        test_write(fake_tls, network_test_frame4)

        s = WebSocketClient.TLSBufferedIO(fake_tls)
        @fact read(s, Frame) --> test_frame1
        @fact read(s, Frame) --> network_test_frame4
    end

    context("Write frames via TLSBufferedIO") do
        fake_tls = FakeTLSStream()
        s = WebSocketClient.TLSBufferedIO(fake_tls)

        mark(fake_tls.write_buf)
        write(s, test_frame1)
        write(s, network_test_frame4)
        reset(fake_tls.write_buf)
        @fact read(fake_tls.write_buf, Frame) --> test_frame1
        @fact read(fake_tls.write_buf, Frame) --> network_test_frame4
    end
end