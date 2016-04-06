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
        reader_task = WebSocketClient.start_reader(s)
        sleep(0.1)
        @fact reader_task --> istaskstarted
        @fact reader_task --> x -> !istaskdone(x)

        # Stop reader task
        # Check that it isn't running.
        WebSocketClient.stop_reader(reader_task)
        @fact istaskdone(reader_task) --> true
    end

    context("Read a frame and stop") do
        framebuf = IOBuffer(Array{UInt8, 1}(), true, true)
        write(framebuf, test_frame1)
        iobuf = IOBuffer(takebuf_array(framebuf))
        s = BlockingStream(iobuf)

        @sync begin
            reader_task = WebSocketClient.start_reader(s)

            @async begin
                actual_frame = consume(reader_task)
                @fact actual_frame --> test_frame1

                WebSocketClient.stop_reader(reader_task)
                sleep(0.1)
                @fact reader_task --> istaskdone
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

        @sync begin
            reader_task = WebSocketClient.start_reader(s)

            @async begin
                actual_frame1 = consume(reader_task)
                @fact actual_frame1 --> test_frame1

                actual_frame2 = consume(reader_task)
                @fact actual_frame2 --> test_frame2

                actual_frame3 = consume(reader_task)
                @fact actual_frame3 --> test_frame3

                WebSocketClient.stop_reader(reader_task)
                sleep(0.1)
                @fact reader_task --> istaskdone
            end
        end
    end
end


