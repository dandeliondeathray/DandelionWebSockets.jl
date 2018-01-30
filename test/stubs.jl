using DandelionWebSockets
using DandelionWebSockets: STATE_OPEN, STATE_CONNECTING, STATE_CLOSING, STATE_CLOSED
using DandelionWebSockets: SocketState, AbstractPonger, SendTextFrame, FrameFromServer
using DandelionWebSockets: AbstractWriterTaskProxy, masking!
import DandelionWebSockets: write, pong_received, ping_sent
import Base: write

"InvalidPrecondition signals that a precondition to running the test was not met."
struct InvalidPrecondition <: Exception
    message::String
end

#
# WebSocketHandlerStub
#

"WebSocketHandlerStub acts as a handler for the tests, storing state and incoming messages."
mutable struct WebSocketHandlerStub <: WebSocketHandler
    state::SocketState
    texts::Vector{String}
    binaries::Vector{Vector{UInt8}}

    WebSocketHandlerStub() = new(STATE_CONNECTING, Vector{String}(), Vector{Vector{UInt8}}())
end

state_closed(h::WebSocketHandlerStub) = h.state = STATE_CLOSED
state_closing(h::WebSocketHandlerStub) = h.state = STATE_CLOSING
state_connecting(h::WebSocketHandlerStub) = h.state = STATE_CONNECTING
state_open(h::WebSocketHandlerStub) = h.state = STATE_OPEN
on_text(h::WebSocketHandlerStub, text::String) = push!(h.texts, text)
on_binary(h::WebSocketHandlerStub, binary::Vector{UInt8}) = push!(h.binaries, binary)


function getsingletext(h::WebSocketHandlerStub)
    if length(h.texts) == 0
        throw(InvalidPrecondition("exactly one text was expected, but none were received"))
    end
    if length(h.texts) > 1
        throw(InvalidPrecondition("exactly one text was expected, but more than one was received: $(h.texts)"))
    end

    h.texts[1]
end

function gettextat(h::WebSocketHandlerStub, i::Int)
    if length(h.texts) < i
        throw(InvalidPrecondition(
            "require text at index $i, but only $(length(h.texts)) messages received"))
    end
    h.texts[i]
end

function getbinaryat(h::WebSocketHandlerStub, i::Int)
    if length(h.binaries) < i
        throw(InvalidPrecondition(
            "require binary at index $i, but only $(length(h.binaries)) messages received"))
    end
    h.binaries[i]
end

#
# WriterStub
#

struct FrameWriterStub <: IO
    frames::Vector{Frame}

    FrameWriterStub() = new(Vector{Frame}())
end

write(w::FrameWriterStub, frame::Frame) = push!(w.frames, frame)

function getframe(w::FrameWriterStub, i::Int)
    if length(w.frames) < i
        throw(InvalidPrecondition("required frame at index $i, but only has $(length(w.frames))"))
    end
    w.frames[i]
end

function getframeunmasked(w::FrameWriterStub, i::Int, mask::Vector{UInt8})
    frame = getframe(w, i)
    masking!(frame.payload, mask)
    frame
end

get_no_of_frames_written(w::FrameWriterStub) = length(w.frames)

#
# Ponger stub
#

mutable struct PongerStub <: AbstractPonger
    no_of_pongs::Int
    no_of_pings_sent::Int

    PongerStub() = new(0, 0)
end

ping_sent(p::PongerStub) = p.no_of_pings_sent += 1
pong_received(p::PongerStub) = p.no_of_pongs += 1

#
# A fake RNG allows us to deterministically test functions that would otherwise behave
# pseudo-randomly.
#

mutable struct FakeRNG{T} <: AbstractRNG
    values::Array{T, 1}

    FakeRNG{T}(v::Array{T, 1}) where {T} = new{T}(copy(v))
end

FakeRNG{T}(::Type{T}) = FakeRNG{T}(Array{T, 1}())

function Base.rand{T}(rng::FakeRNG, ::Type{T}, n::Int)
    if isempty(rng.values)
        throw(InvalidPrecondition("FakeRNG requires more random data"))
    end
    splice!(rng.values, 1:n)
end
