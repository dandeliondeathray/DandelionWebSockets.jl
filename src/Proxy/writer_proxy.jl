using DandelionWebSockets: Frame
import Base: write, close

export WriterProxy

abstract type WriteRequest end;

struct WriteFrame <: WriteRequest
    frame::Frame
end

struct CloseSocket <: WriteRequest end

struct WriterProxy <: IO
    channel::Channel{WriteRequest}
    writer::IO

    function WriterProxy(writer::IO)
        proxy = new(Channel{WriteRequest}(Inf), writer)
        @schedule run_writerproxy(proxy)
        proxy
    end
end

function run_writerproxy(w::WriterProxy)
    for writerequest in w.channel
        if writerequest == CloseSocket()
            close(w.writer)
            break
        end
        write(w.writer, writerequest.frame)
    end
end

write(w::WriterProxy, frame::Frame) = put!(w.channel, WriteFrame(frame))
stopproxy(w::WriterProxy) = close(w.channel)
close(w::WriterProxy) = put!(w.channel, CloseSocket())