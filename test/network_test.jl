import Base: read, write, readavailable, readbytes!, eof
import DandelionWebSockets:
    start, stop, WriterTaskProxy, FrameFromServer, SocketClosed, ClientLogicTaskProxy
using BufferedStreams


network_test_frame4 =
    Frame(true, false, false, false, OPCODE_BINARY, false, 126, 256, nomask, zero256)

facts("Reader task") do
    context("Start and stop") do
        # Start async reader task
        # Check that it's running.
        s = BlockingStream(IOBuffer())
        logic = MockClientLogic([
            (:handle, Any[SocketClosed()])
        ])

        logic_proxy = ClientLogicTaskProxy(logic)
        start(logic_proxy)

        @sync begin
            @async begin
                reader = DandelionWebSockets.start_reader(s, logic_proxy)
                sleep(0.3)
                @fact reader.task --> istaskstarted
                @fact reader.task --> not(istaskdone)

                # Stop reader task
                # Check that it isn't running.
                DandelionWebSockets.stop_reader(reader)
                sleep(0.3)
                @fact istaskdone(reader.task) --> true
            end
        end

        check(logic)
    end

    context("Start and stop, with one frame read") do
        framebuf = IOBuffer(Array{UInt8, 1}(), true, true)
        write(framebuf, test_frame1)
        iobuf = IOBuffer(takebuf_array(framebuf))
        s = BlockingStream(iobuf)
        logic = MockClientLogic([
            (:handle, Any[FrameFromServer(test_frame1)]),
            (:handle, Any[SocketClosed()])
        ])

        logic_proxy = ClientLogicTaskProxy(logic)
        start(logic_proxy)

        @sync begin
            @async begin
                reader = DandelionWebSockets.start_reader(s, logic_proxy)
                sleep(0.3)
                @fact reader.task --> istaskstarted
                @fact reader.task --> not(istaskdone)

                # Stop reader task
                # Check that it isn't running.
                DandelionWebSockets.stop_reader(reader)
                sleep(0.3)
                @fact istaskdone(reader.task) --> true
            end
        end

        check(logic)
    end

    context("Read a frame and stop") do
        framebuf = IOBuffer(Array{UInt8, 1}(), true, true)
        write(framebuf, test_frame1)
        iobuf = IOBuffer(takebuf_array(framebuf))
        s = BlockingStream(iobuf)

        logic = MockClientLogic([
            (:handle, Any[FrameFromServer(test_frame1)]),
            (:handle, Any[SocketClosed()])
        ])

        logic_proxy = ClientLogicTaskProxy(logic)
        start(logic_proxy)

        @sync begin
            @async begin
                reader = DandelionWebSockets.start_reader(s, logic_proxy)
                sleep(0.3)
                DandelionWebSockets.stop_reader(reader)
                sleep(0.3)
                @fact reader.task --> istaskdone
            end
        end
    end

    context("Read several frames and stop") do
        framebuf = IOBuffer(Array{UInt8, 1}(), true, true)
        write(framebuf, test_frame1)
        write(framebuf, test_frame2)
        write(framebuf, test_frame3)
        iobuf = IOBuffer(takebuf_array(framebuf))
        s = BlockingStream(iobuf)

        logic = MockClientLogic([
            (:handle, Any[FrameFromServer(test_frame1)]),
            (:handle, Any[FrameFromServer(test_frame2)]),
            (:handle, Any[FrameFromServer(test_frame3)]),
            (:handle, Any[SocketClosed()])
        ])

        logic_proxy = ClientLogicTaskProxy(logic)
        start(logic_proxy)

        @sync begin
            @async begin
                reader = DandelionWebSockets.start_reader(s, logic_proxy)
                sleep(0.005)
                DandelionWebSockets.stop_reader(reader)
                sleep(0.005)
                @fact reader.task --> istaskdone
            end
        end
    end
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

    FakeTLSStream() = new(IOBuffer())
end

test_write(s::FakeTLSStream, frame::Frame) = write(s.buf, frame)
function write(s::FakeTLSStream, frame::Frame)
    mark(s.buf)
    write(s.buf, frame)
    reset(s.buf)
end

write(s::FakeTLSStream, t::UInt8) = write(s.buf, t)
write(s::FakeTLSStream, t::UInt16) = write(s.buf, t)
write(s::FakeTLSStream, t::UInt64) = write(s.buf, t)

read{T}(::FakeTLSStream, ::T) = throw(ErrorException())
readavailable(s::FakeTLSStream) = throw(ErrorException())

readbytes!(ctx::FakeTLSStream, buf::Vector{UInt8}, nbytes=length(buf)) =
    readbytes!(ctx.buf, buf, UInt(nbytes))

readbytes!(ctx::FakeTLSStream, buf::Vector{UInt8}, nbytes::UInt) = readbytes!(ctx.buf, buf, nbytes)
eof(f::FakeTLSStream) = eof(f.buf)

facts("Byte stream from SSL socket") do
    # MbedTLS.SSLContext does not allow you to read byte s from the IO stream. It throws an
    # exception if you try. `BufferedStreams` adapts the TLS stream to support byte I/O.
    context("Read two bytes via BufferedStreams") do
        fake_tls = FakeTLSStream()
        mark(fake_tls.buf)
        write(fake_tls.buf, Vector{UInt8}([1,2]))
        reset(fake_tls.buf)

        s = BufferedInputStream(fake_tls)

        @fact read(s, UInt8) --> 1
        @fact read(s, UInt8) --> 2
    end

    context("Read frames via BufferedStreams") do
        fake_tls = FakeTLSStream()
        mark(fake_tls.buf)
        test_write(fake_tls, test_frame1)
        test_write(fake_tls, network_test_frame4)
        reset(fake_tls.buf)

        s = BufferedInputStream(fake_tls)
        @fact read(s, Frame) --> test_frame1
        @fact read(s, Frame) --> network_test_frame4
    end

    context("Write frames via BufferedStreams") do
        fake_tls = FakeTLSStream()
        s = BufferedOutputStream(fake_tls)

        mark(fake_tls.buf)
        write(s, test_frame1)
        write(s, network_test_frame4)
        flush(s)
        reset(fake_tls.buf)
        @fact read(fake_tls.buf, Frame) --> test_frame1
        @fact read(fake_tls.buf, Frame) --> network_test_frame4
    end
end