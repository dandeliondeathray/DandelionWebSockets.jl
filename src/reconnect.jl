# Contains code for reconnecting a WebSocket.
#
# Retrying is done using "backoff", so that it doesn't retry too often. The backoffs are done in two
# layers. The first calculates a fixed backoff based on the atan trigonometric function. This is
# defined so that it will reach about 90% of the max backoff after 12 attempts.
# The other layer is a randomization of the previous backoff, jiggling the timeout a few seconds
# longer or shorter.

import Base: reset

export AbstractBackoff, Backoff, RandomizedBackoff, reset, backoff_min, backoff_max
export AbstractRetry, Retry, retry, set_function

abstract AbstractBackoff

"A backoff that follows a atan curve, and reaches about 90% of max backoff in 12 attempts."
type Backoff <: AbstractBackoff
    min::Float64
    max::Float64
    state::Int

    Backoff(min::Float64, max::Float64) = new(min, max, 0)
end

"Reset the backoff to its initial state."
reset(b::Backoff) = b.state = 0

backoff_min(b::Backoff) = b.min
backoff_max(b::Backoff) = b.max

"Get the next backoff value."
function call(b::Backoff)
    v = b.min + atan(b.state*b.state/32) * 2 / pi * (b.max - b.min)
    b.state += 1
    v
end

"Randomize another backoff by adding some randomness to the backoff time."
type RandomizedBackoff <: AbstractBackoff
    backoff::AbstractBackoff
    rng::AbstractRNG
    interval::Float64
end

show(io::IO, r::RandomizedBackoff) = show(io, "RandomizedBackoff($(r.backoff), $(r.interval))")

reset(b::RandomizedBackoff) = reset(b.backoff)
backoff_min(b::RandomizedBackoff) = backoff_min(b.backoff)
backoff_max(b::RandomizedBackoff) = backoff_max(b.backoff)

function call(b::RandomizedBackoff)
    (r,) = (rand(b.rng, Float64, 1) - 0.5) * 2 * b.interval
    v = b.backoff()
    max(backoff_min(b), min(backoff_max(b), v + r))
end

abstract AbstractRetry

default_timer_factory = (f, d) -> Timer(f, d)

"Start a timer for some function, based on a backoff."
type Retry <: AbstractRetry
    backoff::AbstractBackoff
    fun::Function
    timer_fun::Function

    Retry(backoff::AbstractBackoff, fun::Function;
          timer_fun::Function=default_timer_factory) = new(backoff, (t) -> fun(), timer_fun)
end

function retry(r::Retry)
    backoff_time = r.backoff()
    r.timer_fun(r.fun, backoff_time)
end

reset(r::Retry) = reset(r.backoff)

set_function(r::Retry, f::Function) = r.fun = (t) -> f()