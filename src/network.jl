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
        end
    end
    ServerReader(s, chan, t)
end


function stop_reader(t::ServerReader)
    try
        close(t.chan)
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