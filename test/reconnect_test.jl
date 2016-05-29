import DandelionWebSockets: Backoff, reset

facts("Reconnect") do
    context("Backoff") do
        min = 30.0
        max = 200.0
        backoff_range = max - min
        backoff = Backoff(min, max)

        values = [backoff() for i in range(1, 12)]

        # The first three attempts won't reach half the backoff range.
        for i in range(1, 3)
            @fact values[i] < 0.5 * backoff_range --> true
        end

        # After twelve attempts the backoff is over 90% of the backoff range.
        @fact values[12] > 0.9 * backoff_range --> true
    end

    context("Backoff reset") do
        backoff = Backoff(0.0, 100.0)
        values = [backoff() for i in range(1, 12)]
        reset(backoff)
        @fact backoff() --> 0.0
    end

    context("Backoff limits") do
        min = 30.0
        max = 200.0
        backoff = Backoff(min, max)
        values = [backoff() for i in range(1, 100)]
        for v in values
            @fact v >= min --> true
            @fact v <= max --> true
        end
    end
end