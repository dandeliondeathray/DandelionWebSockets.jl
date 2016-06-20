export Pinger, stop,
       Ponger, pong_received, attach, ping_sent

type Pinger <: AbstractPinger
    timer::Nullable{Timer}
    interval::Float64

    function Pinger(interval::Float64)
        new(Nullable{Timer}(), interval)
    end
end

function attach(pinger::Pinger, logic::AbstractClientTaskProxy)
    send_ping = x -> handle(logic, ClientPingRequest())
    pinger.timer = Nullable{Timer}(Timer(send_ping, pinger.interval, pinger.interval))
end

function stop(p::Pinger)
    if !isnull(p.timer)
        close(get(p.timer))
        p.timer = Nullable{Timer}()
    end
end

type Ponger <: AbstractPonger
    timeout::Float64
    pong_missed::Function
    pongs_received::UInt64

    Ponger(timeout::Float64) = new(timeout, x -> nothing, 0)
end

function start_timer_(p::Ponger)
    p.timer = Nullable{Timer}(Timer(p.pong_missed, p.timeout, p.timeout))
end

attach(ponger::Ponger, logic::AbstractClientTaskProxy) =
    ponger.pong_missed = () -> handle(logic, PongMissed())

pong_received(ponger::Ponger) = ponger.pongs_received += 1

function ping_sent(ponger::Ponger)
    pongs_received_at_send = ponger.pongs_received
    fun = x -> begin
        if ponger.pongs_received == pongs_received_at_send
            ponger.pong_missed()
        end
    end
    Timer(fun, ponger.timeout)
end
