import Base: read, write, readavailable
import DandelionWebSockets:
    start, start_reader, stop, WriterTaskProxy, FrameFromServer, SocketClosed, ClientProtocolTaskProxy


network_test_frame4 =
    Frame(true, false, false, false, OPCODE_BINARY, false, 126, 256, nomask, zero256)

facts("Reader task") do
    context("Start and stop") do
        # Start async reader task
        # Check that it's running.
        s = BlockingStream(IOBuffer())
        logic = MockClientProtocol([
            (:handle, Any[SocketClosed()])
        ])

        logic_proxy = ClientProtocolTaskProxy(logic)
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
        iobuf = IOBuffer(take!(framebuf))
        s = BlockingStream(iobuf)
        logic = MockClientProtocol([
            (:handle, Any[FrameFromServer(test_frame1)]),
            (:handle, Any[SocketClosed()])
        ])

        logic_proxy = ClientProtocolTaskProxy(logic)
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
        iobuf = IOBuffer(take!(framebuf))
        s = BlockingStream(iobuf)

        logic = MockClientProtocol([
            (:handle, Any[FrameFromServer(test_frame1)]),
            (:handle, Any[SocketClosed()])
        ])

        logic_proxy = ClientProtocolTaskProxy(logic)
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
        iobuf = IOBuffer(take!(framebuf))
        s = BlockingStream(iobuf)

        logic = MockClientProtocol([
            (:handle, Any[FrameFromServer(test_frame1)]),
            (:handle, Any[FrameFromServer(test_frame2)]),
            (:handle, Any[FrameFromServer(test_frame3)]),
            (:handle, Any[SocketClosed()])
        ])

        logic_proxy = ClientProtocolTaskProxy(logic)
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

