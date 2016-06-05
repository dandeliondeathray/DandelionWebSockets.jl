import Base: read, write

# TODO: Documentation

type StopTaskException <: Exception end

abstract AbstractServerReader

immutable ServerReader <: AbstractServerReader
    s::IO
    task::Task
end

function do_reader(s::IO, logic::AbstractClientTaskProxy)
    println("Reader task started")
    try
        while true
            frame = read(s, Frame)
            println("Read frame: $frame")
            handle(logic, FrameFromServer(frame))
        end
    catch ex
        # TODO: Handle errors better.
        println("DandelionWebSockets.start_reader exception: $(ex)")
    end
    handle(logic, SocketClosed())
end

function start_reader(s::IO, logic::AbstractClientTaskProxy)
    t = @schedule do_reader(s, logic)
    ServerReader(s, t)
end


function stop(t::ServerReader)
    try
        Base.throwto(t.task, StopTaskException())
    end
end
