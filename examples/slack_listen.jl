#!/usr/bin/env julia

# This example connects to the Slack RTM API, which is its WebSocket API for
# sending and receiving messages. It simply prints all JSON events.
# 
# This example requires a Slack bot token as the first and only argument on the
# command line.

using HTTP
using JSON
using DandelionWebSockets
import DandelionWebSockets: on_text, on_binary
import DandelionWebSockets: state_connecting, state_open,
                            state_closing, state_closed


# This WebSocketHandler prints all incoming text and binary events.
# When the connection is closed, then it notifies the stop channel.
mutable struct SlackListener <: WebSocketHandler
    connection::Union{WebSocketConnection, Nothing}

    stop_channel::Channel{Any}

    SlackListener(chan::Channel{Any}) = new(nothing, chan)
end

on_text(handler::SlackListener, text::String) = println(text)
on_binary(handler::SlackListener, data::Vector{UInt8}) = println(data)

state_connecting(handler::SlackListener, connection::WebSocketConnection) = handler.connection = connection
state_open(handler::SlackListener)       = println("State: OPEN")
state_closing(handler::SlackListener)    = println("State: CLOSING")
function state_closed(handler::SlackListener)
    println("State: CLOSED")
    put!(handler.stop_channel, true)
end

# The main script starts here, by validating the command line arguments,
# and reading the token.
if length(ARGS) < 1 || length(ARGS) > 1
    println("Usage: julia slack_listen.jl <token>")
    println("")
    println("    Connect to the Slack RTM API and print all events.")
    println("")
    exit(1)
end
token=strip(ARGS[1])

# First make an HTTP GET request using the token. This results in a URL which we
# can use to connect to the WebSocket API.
connecturi = "https://slack.com/api/rtm.connect"
query = "token=$token"
connectresponse = HTTP.get(connecturi; query=query)
responsejson = JSON.parse(String(connectresponse.body))

# Print error message if the response was unsuccessful.
if !responsejson["ok"]
    msg = responsejson["error"]
    println("Connect error: $msg")
    exit(1)
end

botname = responsejson["self"]["name"]
println("Name: $botname")

# This is the URL we need to connect to.
rtmurl = responsejson["url"]

# Create a WebSocket client.
stop_chan = Channel{Any}(3)
client = WSClient()
handler = SlackListener(stop_chan)

ok = wsconnect(client, rtmurl, handler)
if !ok
    println("WebSocket connection failed!")
    exit(1)
end

# Wait until the connection is closed.
take!(stop_chan)
