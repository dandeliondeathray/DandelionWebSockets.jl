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
end

# These are called when you get text/binary frames, respectively.
on_text(::EchoHandler, s::String)  = println("Received text: $s")
on_binary(::EchoHandler, data::Vector{UInt8}) = println("Received data: $data")

# These are called when the WebSocket state changes.

state_closing(::EchoHandler)    = println("State: CLOSING")
state_connecting(::EchoHandler) = println("State: CONNECTING")

# Called when the connection is open, and ready to send/receive messages.
function state_open(handler::EchoHandler)
    println("State: OPEN")

    # Send some text frames, and a binary frame.
    @schedule begin
        texts = ["Hello", "world", "!"]

        for text in texts
            println("Sending  text: $text")
            send_text(handler.client, text)
            sleep(0.5)
        end

        send_binary(handler.client, b"Hello, binary!")
        sleep(0.5)

        # Signal the script that we're done sending all messages.
        # The script will then close the connection.
        put!(stop_chan, true)
    end
end

function state_closed(::EchoHandler)
    println("State: CLOSED")

    # Signal the script that the connection is closed.
    put!(stop_chan, true)
end

stop_chan = Channel{Any}(3)

# Create a WSClient, which we can use to connect and send frames.
client = WSClient()

handler = EchoHandler(client, stop_chan)

uri = URI("ws://echo.websocket.org")
println("Connecting to $uri... ")

wsconnect(client, uri, handler)

println("Connected.")

# The first message on `stop_chan` indicates that all messages have been sent, and we should
# close the connection.
take!(stop_chan)

stop(client)

# The second message on `stop_chan` indicates that the connection is closed, so we can exit.
take!(stop_chan)
