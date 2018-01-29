# Pinger ensures that pings are sent regularly. It is a thin wrapper around a timer and an
# AbstractClientLogic object.
# Ponger ensures that pongs are received regularly. The logic tells Ponger whenever a pong response
# is received, and Ponger in return tells the logic when a pong has not been received in the
# expected timeframe.

import DandelionWebSockets: ClientPingRequest, handle, PongMissed

type FakeLogic <: AbstractClientLogic
    ping_requests::Int
    pongs_missed::Int

    FakeLogic() = new(0, 0)
end

handle(logic::FakeLogic, ::ClientPingRequest) = logic.ping_requests += 1
handle(logic::FakeLogic, ::PongMissed) = logic.pongs_missed += 1

facts("Pinger/Ponger") do
    context("Sending pings") do
        logic = FakeLogic()
        interval = 0.1
        pinger = Pinger(interval)
        attach(pinger, logic)

        sleep(3 * interval + 0.02)
        stop(pinger)

        @fact logic.ping_requests --> 3

        # Check that the pinger stopped.
        sleep(3 * interval)
        @fact logic.ping_requests --> 3
    end

    context("Missed pong") do
        logic = FakeLogic()
        timeout = 0.1

        ponger = Ponger(timeout)
        attach(ponger, logic)

        for i in range(1, 3)
            ping_sent(ponger)
            sleep(timeout + 0.02)
        end

        @fact logic.pongs_missed --> 3

        sleep(3 * timeout)
        @fact logic.pongs_missed --> 3
    end

    context("Disconnect only after three pong misses") do
        logic = FakeLogic()
        timeout = 0.1

        ponger = Ponger(timeout; misses=3)
        attach(ponger, logic)

        ping_sent(ponger)
        sleep(timeout + 0.02)

        @fact logic.pongs_missed --> 0

        ping_sent(ponger)
        sleep(timeout + 0.02)
        @fact logic.pongs_missed --> 0

        ping_sent(ponger)
        sleep(timeout + 0.02)
        @fact logic.pongs_missed --> 1

        sleep(3 * timeout)
        @fact logic.pongs_missed --> 1


        for i in range(1, 6)
            ping_sent(ponger)
            sleep(timeout + 0.02)
        end

        @fact logic.pongs_missed --> 3
    end

    context("Only expect a pong after a ping") do
        logic = FakeLogic()
        timeout = 0.1

        ponger = Ponger(timeout)
        attach(ponger, logic)

        ping_sent(ponger)
        sleep(3 * timeout + 0.02)

        @fact logic.pongs_missed --> 1
    end

    context("Receiving pongs") do
        logic = FakeLogic()
        timeout = 0.1

        ponger = Ponger(timeout)
        attach(ponger, logic)

        for i in range(1, 5)
            ping_sent(ponger)
            sleep(timeout / 2.0)
            pong_received(ponger)
        end

        @fact logic.pongs_missed --> 0
    end
end