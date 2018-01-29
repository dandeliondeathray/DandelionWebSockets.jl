using DandelionWebSockets: Frame
import Base: write

export WriterProxy

struct WriterProxy
    channel::Channel{Frame}
    writer::IO

    function WriterProxy(writer::IO)
        proxy = new(Channel{Frame}(Inf), writer)
        @schedule run_writerproxy(proxy)
        proxy
    end
end

function run_writerproxy(w::WriterProxy)
    for frame in w.channel
        write(w.writer, frame)
    end
end

write(w::WriterProxy, frame::Frame) = put!(w.channel, frame)
stopproxy(w::WriterProxy) = close(w.channel)