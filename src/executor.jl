import Base.==

abstract AbstractClientExecutor

#
# Implementation of ClientLogicExecutor
#

# TODO: These types will go when we have a general pump. Then we'll specify exacts calls to be made
#       on the receiver.
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
immutable StateClosed <: HandlerType end
immutable StateClosing <: HandlerType end

# TODO: This should be as general as the pump suggested in glue.jl. It should be able to support a
#       number of channels, and for each method we'll specify which channel should be used, and what
#       function will be called on the other end. Rather, maybe we should say that the function call
#       will be the same on the sending and receiving end, so we'll only specify it one.
type ClientExecutor <: AbstractClientExecutor
    frame_chan::Channel{Frame}
    user_chan::Channel{HandlerType}
end

# `send_frame` is called when a frame should be sent to the server.
send_frame(t::ClientExecutor, frame::Frame) = put!(t.frame_chan, frame)

# These are callbacks for state changes to the WebSocket.
state_connecting(t::ClientExecutor) = put!(t.user_chan, StateConnecting())
state_open(t::ClientExecutor) = put!(t.user_chan, StateOpen())
state_closed(t::ClientExecutor) = put!(t.user_chan, StateClosed())
state_closing(t::ClientExecutor) = put!(t.user_chan, StateClosing())

# Callback when a text message is received from the server. Note that it's the entire message, not
# individual frames.
on_text(t::ClientExecutor, text::UTF8String) = put!(t.user_chan, OnText(text))
# Callback when a binary message is received from the server. Note that it's the entire message, not
# individual frames.
on_binary(t::ClientExecutor, data::Vector{UInt8}) = put!(t.user_chan, OnBinary(data))