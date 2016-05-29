import Base: reset

abstract AbstractBackoff

type Backoff <: AbstractBackoff
    min::Float64
    max::Float64
    state::Int

    Backoff(min::Float64, max::Float64) = new(min, max, 0)
end

reset(b::Backoff) = b.state = 0

function call(b::Backoff)
    v = b.min + atan(b.state*b.state/32) * 2 / pi * (b.max - b.min)
    b.state += 1
    v
end

