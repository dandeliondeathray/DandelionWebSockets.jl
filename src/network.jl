import Base: read, write

# TODO: Documentation

type StopTaskException <: Exception end

immutable ServerReader
    s::IO
    chan::Channel
    task::Task
end

function start_reader(s::IO, chan::Channel)
    t = @async begin
        try
            while true
                frame = read(s, Frame)
                put!(chan, FrameFromServer(frame))
            end
        catch ex
            # TODO: Handle errors better.
            println("WebSocketClient.start_reader exception: $(ex)")
        end
        put!(chan, SocketClosed())
    end
    ServerReader(s, chan, t)
end


function stop_reader(t::ServerReader)
    try
        Base.throwto(t.task, StopTaskException())
    end
end

immutable ClientWriter
    s::IO
    chan::Channel
    task::Task
end

function start_writer(s::IO, chan::Channel)
    t = @async begin
        try
            for frame in chan
                write(s, frame)
            end
            # TODO: Handle errors better.
        end
    end
    ClientWriter(s, chan, t)
end

function stop_writer(t::ClientWriter)
    close(t.chan)
end


#
# TLSBufferedIO adapts a TLS socket so we can do byte I/O.
#

immutable TLSBufferedIO <: IO
    tls_stream::IO
    buf::IOBuffer

    TLSBufferedIO(tls_stream::IO) = new(tls_stream, IOBuffer())
end

function fill_buffer(s::TLSBufferedIO, n::Int)
    begin_ptr = mark(s.buf)
    while s.buf.size - begin_ptr < n
        write(s.buf, readavailable(s.tls_stream))
    end
    reset(s.buf)
end

function read(s::TLSBufferedIO, t::Type{UInt8})
    fill_buffer(s, sizeof(t))
    read(s.buf, t)
end

function read(s::TLSBufferedIO, t::Type{UInt16})
    fill_buffer(s, sizeof(t))
    read(s.buf, t)
end

function read(s::TLSBufferedIO, t::Type{UInt64})
    fill_buffer(s, sizeof(t))
    read(s.buf, t)
end

function read(s::TLSBufferedIO, t::Type{UInt8}, n::Int)
    fill_buffer(s, sizeof(t) * n)
    read(s.buf, t, n)
end

write(s::TLSBufferedIO, t::UInt8) = write(s.tls_stream, t)
write(s::TLSBufferedIO, t::UInt16) = write(s.tls_stream, t)
write(s::TLSBufferedIO, t::UInt64) = write(s.tls_stream, t)
