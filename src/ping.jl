export Pinger, stop,
       Ponger, pong_received, attach, ping_sent

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
