import Base.==

#
# Abstract outbound interface for ClientLogic
#

abstract AbstractClientExecutor

# `send_frame` is called when a frame should be sent to the server.
send_frame(t::AbstractClientExecutor, ::Frame) = error("send_frame undefined for $(t)")

# These are callbacks for state changes to the WebSocket.
state_open(t::AbstractClientExecutor)          = error("state_open undefined for $(t)")
state_closing(t::AbstractClientExecutor)       = error("state_closing undefined for $(t)")
state_closed(t::AbstractClientExecutor)        = error("state_closed undefined for $(t)")

# Callback when a text message is received from the server. Note that it's the entire message, not
# individual frames.
text_received(t::AbstractClientExecutor, ::UTF8String) =
    error("text_received undefined for $(t)")

# Callback when a binary message is received from the server. Note that it's the entire message, not
# individual frames.
data_received(t::AbstractClientExecutor, ::Array{UInt8, 1}) =
    error("data_received undefined for $(t)")

#
# Implementation of ClientLogicExecutor
#

abstract HandlerType

immutable TextReceived <: HandlerType
    text::UTF8String
end

==(a::TextReceived, b::TextReceived) = a.text == b.text

type ClientExecutor <: AbstractClientExecutor
    frame_chan::Channel{Frame}
    user_chan::Channel{HandlerType}
end

send_frame(t::ClientExecutor, frame::Frame) = put!(t.frame_chan, frame)
text_received(t::ClientExecutor, text::UTF8String) = put!(t.user_chan, TextReceived(text))
