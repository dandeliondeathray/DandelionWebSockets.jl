import Base: read, write, readavailable
import DandelionWebSockets:
    start, start_reader, stop, WriterTaskProxy, FrameFromServer, SocketClosed, ClientLogicTaskProxy


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
                reader = start_reader(s, logic_proxy)
                sleep(0.3)
                @fact reader.task --> istaskstarted
                @fact reader.task --> not(istaskdone)

                # Stop reader task
                # Check that it isn't running.
                stop(reader)
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
                reader = start_reader(s, logic_proxy)
                sleep(0.3)
                @fact reader.task --> istaskstarted
                @fact reader.task --> not(istaskdone)

                # Stop reader task
                # Check that it isn't running.
                stop(reader)
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
                reader = start_reader(s, logic_proxy)
                sleep(0.3)
                stop(reader)
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
                reader = start_reader(s, logic_proxy)
                sleep(0.005)
                stop(reader)
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

        s = DandelionWebSockets.TLSBufferedIO(fake_tls)

        @fact read(s, UInt8) --> 1
        @fact read(s, UInt8) --> 2
    end

    context("Read frames via TLSBufferedIO") do
        fake_tls = FakeTLSStream()
        test_write(fake_tls, test_frame1)
        test_write(fake_tls, network_test_frame4)

        s = DandelionWebSockets.TLSBufferedIO(fake_tls)
        @fact read(s, Frame) --> test_frame1
        @fact read(s, Frame) --> network_test_frame4
    end

    context("Write frames via TLSBufferedIO") do
        fake_tls = FakeTLSStream()
        s = DandelionWebSockets.TLSBufferedIO(fake_tls)

        mark(fake_tls.write_buf)
        write(s, test_frame1)
        write(s, network_test_frame4)
        reset(fake_tls.write_buf)
        @fact read(fake_tls.write_buf, Frame) --> test_frame1
        @fact read(fake_tls.write_buf, Frame) --> network_test_frame4
    end
end