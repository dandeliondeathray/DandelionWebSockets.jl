# Example of DandelionWebSocket.jl:
# Send some text and binary frames to ws://echo.websocket.org,
# which echoes them back.

using Requests: URI

using DandelionWebSockets

# Explicitly import the callback functions that we're going to add more methods for.
import DandelionWebSockets: on_text, on_binary,
                            state_connecting, state_open, state_closing, state_closed

# A simple WebSocketHandler which sends a few messages, receives echoes back, and then sends a stop
# signal via a channel when it's done.
mutable struct EchoHandler <: WebSocketHandler
    client::WSClient
    stop_channel::Channel{Any}
    received::Int
    sent::Int
end

# These are called when you get text/binary frames, respectively.
function on_text(h::EchoHandler, s::String)
    h.received += 1
    send_text(h.client, "foo")
    h.sent += 1
end

function on_binary(h::EchoHandler, data::Vector{UInt8})
    #println("Received data: $data")
    h.received += 1
    send_binary(h.client, b"foo")
    h.sent += 1
end

# These are called when the WebSocket state changes.

function state_closing(::EchoHandler)
    #println("State: CLOSING")
end

function state_connecting(::EchoHandler)
    #println("State: CONNECTING")
end

# Called when the connection is open, and ready to send/receive messages.
function state_open(handler::EchoHandler)
    #println("State: OPEN")

    send_text(handler.client, "Ready.")
end

function state_closed(::EchoHandler)
    #println("State: CLOSED")

    # Signal the script that the connection is closed.
    put!(stop_chan, true)
end

stop_chan = Channel{Any}(3)

# Create a WSClient, which we can use to connect and send frames.
client = WSClient()

handler = EchoHandler(client, stop_chan, 0, 0)

uri = URI("ws://server:8080")
println("Connecting to $uri... ")

wsconnect(client, uri, handler)

println("Connected.")

# The first message on `stop_chan` indicates that the connection is closed, so we can exit.
take!(stop_chan)

println("Received:", handler.received)
println("Sent:    ", handler.sent)
