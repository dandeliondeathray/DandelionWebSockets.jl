# DandelionWebSockets
DandelionWebSockets is a client side WebSocket package.

## Usage
Create a subtype of `WebSocketHandler`, with callbacks for WebSocket events. Create a `WSClient` and
connect to a WebSocket server.

```
type MyHandler <: WebSocketHandler
    client::WSClient
end

# These are called when you get a text or binary frame, respectively.
on_text(handler::MyHandler, text::UTF8String) = ...
on_binary(handler::MyHandler, data::Vector{UInt8}) = ...

# These are called when the state of the WebSocket changes.
state_connecting(handler::MyHandler) = ...
state_open(handler::MyHandler)       = ...
state_closing(handler::MyHandler)    = ...
state_closed(handler::MyHandler)     = ...
```

The following functions are available on `WSClient`, to send frames to the server.

```
send_text(c::WSClient, s::UTF8String)
send_binary(c::WSClient, data::Vector{UInt8})

# Close the WebSocket.
stop(c::WSClient)
```

To connect to a WebSocket server, call
`wsconnect(client::WSClient, uri::URI, handler::WebSocketHandler)`.

## Releases and Julia
TL;DR: If on Julia 0.4 or 0.5, use master. If on Julia 0.6, use branch
`release_1.0.0`.

The current master branch was originally built for julia 0.4, with compatibility
for 0.5 added later.
The branch `release_1.0.0` contains updates for Julia 0.6. Work will continue on
that branch until it's ready for a release, and it's expected that people have
moved on to Julia 0.6. I will then merge it to master and tag it with a release
tag.

## Needs work

- Implement regular pings, to ensure the connection is up.
- Wait for Requests.jl next release.
  This package needs a HTTP Upgrade feature of Requests.jl, which is only present in master, not in
  the release 0.3.7.
- Ability to send multi-frame messages.

## License
DandelionWebSockets is licensed under the MIT license.
