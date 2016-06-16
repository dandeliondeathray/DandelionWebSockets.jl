export Pinger, stop,
       Ponger, pong_received, attach

type Pinger <: AbstractPinger
    timer::Timer

    function Pinger(logic::AbstractClientTaskProxy, interval::Float64)
        send_ping = x -> handle(logic, ClientPingRequest())
        new(Timer(send_ping, interval, interval))
    end
end

stop(p::Pinger) = close(p.timer)

type Ponger <: AbstractPonger
    timeout::Float64
    timer::Nullable{Timer}
    pong_missed::Function

    Ponger(timeout::Float64) = new(timeout, Nullable{Timer}(), x -> nothing)
end

function start_timer_(p::Ponger)
    p.timer = Nullable{Timer}(Timer(p.pong_missed, p.timeout, p.timeout))
end

function attach(ponger::Ponger, logic::AbstractClientTaskProxy)
    ponger.pong_missed = x -> pong_missed(logic)
    start_timer_(ponger)
end

function pong_received(ponger::Ponger)
    stop(ponger)
    start_timer_(ponger)
end

function stop(p::Ponger)
    if !isnull(p.timer)
        close(get(p.timer))
    end
end
