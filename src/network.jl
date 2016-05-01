import Base: read

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
        end
    end
    ClientWriter(s, chan, t)
end

function stop_writer(t::ClientWriter)
    close(t.chan)
end


#
# TLSBufferedReader adapts a TLS socket so we can do byte I/O.
#

immutable TLSBufferedReader <: IO
    tls_stream::IO
    buf::IOBuffer

    TLSBufferedReader(tls_stream::IO) = new(tls_stream, IOBuffer())
end

function fill_buffer(s::TLSBufferedReader, n::Int)
    mark(s.buf)
    while s.buf.size < n
        write(s.buf, readavailable(s.tls_stream))
    end
    reset(s.buf)
end

function read(s::TLSBufferedReader, t::Type{UInt8})
    fill_buffer(s, sizeof(t))
    read(s.buf, t)
end

function read(s::TLSBufferedReader, t::Type{UInt16})
    fill_buffer(s, sizeof(t))
    read(s.buf, t)
end

function read(s::TLSBufferedReader, t::Type{UInt64})
    fill_buffer(s, sizeof(t))
    read(s.buf, t)
end

function read(s::TLSBufferedReader, t::Type{UInt8}, n::Int)
    fill_buffer(s, sizeof(t) * n)
    read(s.buf, t, n)
end