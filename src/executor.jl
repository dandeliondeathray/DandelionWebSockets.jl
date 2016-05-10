import Base.==

#
# Abstract outbound interface for ClientLogic
#

abstract AbstractClientExecutor

# `send_frame` is called when a frame should be sent to the server.
send_frame(t::AbstractClientExecutor, ::Frame) = error("send_frame undefined for $(t)")

# These are callbacks for state changes to the WebSocket.
state_connecting(t::AbstractClientExecutor) = error("state_connecting undefined for $(typeof(t))")
state_open(t::AbstractClientExecutor)       = error("state_open undefined for $(typeof(t))")
state_closing(t::AbstractClientExecutor)    = error("state_closing undefined for $(typeof(t))")
state_closed(t::AbstractClientExecutor)     = error("state_closed undefined for $(typeof(t))")

# Callback when a text message is received from the server. Note that it's the entire message, not
# individual frames.
on_text(t::AbstractClientExecutor, ::UTF8String) = error("on_text undefined for $(typeof(t))")

# Callback when a binary message is received from the server. Note that it's the entire message, not
# individual frames.
on_binary(t::AbstractClientExecutor, ::Vector{UInt8}) =
    error("on_binary undefined for $(typeof(t))")

#
# Implementation of ClientLogicExecutor
#

abstract HandlerType

immutable OnText <: HandlerType
    text::UTF8String
end

immutable OnBinary <: HandlerType
    data::Vector{UInt8}
end

==(a::OnText, b::OnText) = a.text == b.text
==(a::OnBinary, b::OnBinary) = a.data == b.data

immutable StateConnecting <: HandlerType end
immutable StateOpen <: HandlerType end
immutable StateClose <: HandlerType end
immutable StateClosing <: HandlerType end

type ClientExecutor <: AbstractClientExecutor
    frame_chan::Channel{Frame}
    user_chan::Channel{HandlerType}
end

send_frame(t::ClientExecutor, frame::Frame) = put!(t.frame_chan, frame)
state_connecting(t::ClientExecutor) = put!(t.user_chan, StateConnecting())
state_open(t::ClientExecutor) = put!(t.user_chan, StateOpen())
state_closed(t::ClientExecutor) = put!(t.user_chan, StateClose())
state_closing(t::ClientExecutor) = put!(t.user_chan, StateClosing())
on_text(t::ClientExecutor, text::UTF8String) = put!(t.user_chan, OnText(text))
on_binary(t::ClientExecutor, data::Vector{UInt8}) = put!(t.user_chan, OnBinary(data))