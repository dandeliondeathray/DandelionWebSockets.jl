using DandelionWebSockets
using DandelionWebSockets: STATE_OPEN, STATE_CONNECTING, STATE_CLOSING, STATE_CLOSED
using DandelionWebSockets: SocketState, AbstractPonger, SendTextFrame, FrameFromServer

"InvalidPrecondition signals that a precondition to running the test was not met."
struct InvalidPrecondition <: Exception
    message::String
end

#
# WebSocketHandlerStub
#

# TODO: The handler type you send in to ClientLogic should reasonably be a WebSocketHandler type,
#       but because of implementation reasons it needs to be an AbstractHandlerTaskProxy instead.
#       I should change this.
"WebSocketHandlerStub acts as a handler for the tests, storing state and incoming messages."
struct WebSocketHandlerStub <: AbstractHandlerTaskProxy
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

#
# WriterStub
#

struct FrameWriterStub <: AbstractWriterTaskProxy
    frames::Vector{Frame}

    FrameWriterStub() = new(Vector{Frame}())
end

write(w::FrameWriterStub, frame::Frame) = push!(w.frames, frame)

#
# Ponger stub
#

struct PongerStub <: AbstractPonger end

ping_sent(::PongerStub) = nothing
pong_received(::PongerStub) = nothing
