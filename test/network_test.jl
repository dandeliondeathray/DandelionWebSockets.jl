# To accurately test a fake TCPSocket I need a blocking streamk.
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


facts("Reader task") do
    context("Start and stop") do
        # Start async reader task
        # Check that it's running.
        s = BlockingStream(IOBuffer())
        chan = Channel{WebSocketClient.ClientLogicInput}(5)
        reader = WebSocketClient.start_reader(s, chan)
        sleep(0.1)
        @fact reader.task --> istaskstarted
        @fact reader.task --> x -> !istaskdone(x)

        # Stop reader task
        # Check that it isn't running.
        WebSocketClient.stop_reader(reader)
        @fact istaskdone(reader.task) --> true
    end

    context("Read a frame and stop") do
        framebuf = IOBuffer(Array{UInt8, 1}(), true, true)
        write(framebuf, test_frame1)
        iobuf = IOBuffer(takebuf_array(framebuf))
        s = BlockingStream(iobuf)
        chan = Channel{WebSocketClient.ClientLogicInput}(32)

        @sync begin
            reader = WebSocketClient.start_reader(s, chan)

            @async begin
                actual_frame = take!(chan)
                @fact actual_frame.frame --> test_frame1

                WebSocketClient.stop_reader(reader)
                @fact take!(chan) --> WebSocketClient.SocketClosed()
                sleep(0.2)
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
        chan = Channel{WebSocketClient.ClientLogicInput}(5)

        @sync begin
            reader = WebSocketClient.start_reader(s, chan)

            @async begin
                actual_frame1 = take!(chan)
                @fact actual_frame1.frame --> test_frame1

                actual_frame2 = take!(chan)
                @fact actual_frame2.frame --> test_frame2

                actual_frame3 = take!(chan)
                @fact actual_frame3.frame --> test_frame3

                WebSocketClient.stop_reader(reader)
                @fact take!(chan) --> WebSocketClient.SocketClosed()
                sleep(0.1)
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
        chan = Channel{Frame}(32)

        writer = WebSocketClient.start_writer(s, chan)
        sleep(0.05)
        @fact writer.task --> x -> !istaskdone(x)

        WebSocketClient.stop_writer(writer)
        sleep(0.05)
        @fact writer.task --> istaskdone
    end

    context("Write a few frames") do
        s = MockFrameStream(Vector{Frame}())
        chan = Channel{Frame}(32)

        @sync begin
            writer = WebSocketClient.start_writer(s, chan)
            sleep(0.05)
            @fact writer.task --> x -> !istaskdone(x)

            @async begin
                put!(chan, test_frame1)
                put!(chan, test_frame2)
                put!(chan, test_frame3)

                sleep(0.1)
                expect(s, test_frame1)
                expect(s, test_frame2)
                expect(s, test_frame3)

                WebSocketClient.stop_writer(writer)
                sleep(0.1)
                @fact writer.task --> istaskdone
            end
        end
    end
end