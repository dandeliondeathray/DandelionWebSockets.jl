type StopTaskException <: Exception end

function start_reader(s::IO)
    @async begin
        try
            while true
                frame = read(s, Frame)
                produce(frame)
            end
        end
    end
end


function stop_reader(t::Task)
    Base.throwto(t, StopTaskException())
end