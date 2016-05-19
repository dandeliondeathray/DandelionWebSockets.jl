import Base: read, write

# TODO: Documentation

type StopTaskException <: Exception end

immutable ServerReader
    s::IO
    task::Task
end

function start_reader(s::IO, logic::AbstractClientTaskProxy)
    t = @async begin
        try
            while true
                frame = read(s, Frame)
                handle(logic, FrameFromServer(frame))
            end
        catch ex
            # TODO: Handle errors better.
            println("DandelionWebSockets.start_reader exception: $(ex)")
        end
        handle(logic, SocketClosed())
    end
    ServerReader(s, t)
end


function stop_reader(t::ServerReader)
    try
        Base.throwto(t.task, StopTaskException())
    end
end
