# DandelionWebSockets
[![Build Status](https://travis-ci.org/dandeliondeathray/DandelionWebSockets.jl.svg?branch=master)](https://travis-ci.org/dandeliondeathray/DandelionWebSockets.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/7ajck5bv9wxfjxax/branch/master?svg=true)](https://ci.appveyor.com/project/erikedin/dandelionwebsockets-jl/branch/master)

DandelionWebSockets is a client side WebSocket package.

## Usage
Create a subtype of `WebSocketHandler`, with callbacks for WebSocket events. Create a `WSClient` and
connect to a WebSocket server.

```julia
import DandelionWebSockets: on_text, on_binary
import DandelionWebSockets: state_connecting, state_open,
                            state_closing, state_closed

mutable struct MyHandler <: WebSocketHandler
    client::WSClient
end

# These are called when you get a text or binary frame, respectively.
on_text(handler::MyHandler, text::String) = ...
on_binary(handler::MyHandler, data::Vector{UInt8}) = ...

# These are called when the state of the WebSocket changes.
state_connecting(handler::MyHandler) = ...
state_open(handler::MyHandler)       = ...
state_closing(handler::MyHandler)    = ...
state_closed(handler::MyHandler)     = ...
```

The following functions are available on `WSClient`, to send frames to the server.

```julia
send_text(c::WSClient, s::String)
send_binary(c::WSClient, data::Vector{UInt8})

# Close the WebSocket.
stop(c::WSClient)

# Send a multi-frame text message
textsender = sendmultiframetext(client)
sendframe(textsender, "Hello")
sendframe(textsender, "world")
sendframe(textsender, "Goodbye."; isfinal=true)

# Send a multi-frame binary message
binarysender = sendmultiframebinary(client)
sendframe(binarysender, b"Hello")
sendframe(binarysender, b"world")
sendframe(binarysender, b"Goodbye."; isfinal=true)
```

To connect to a WebSocket server, call
`wsconnect(client::WSClient, uri::URI, handler::WebSocketHandler)`.

For the full example code, please check out `examples/echo.jl`.

## Note on I/O and thread safety
Note that print and I/O functions are not thread safe in Julia. Using them in the message and state
callbacks (as is currently done in the examples) may lead to unexpected behaviour, or crashes. See
https://github.com/JuliaLang/julia/issues/17388 for more details.

Thank you to @alessandrousseglioviretta for bringing up this issue.

## Note on SSL
This package requires version 0.5.2 or earlier of MbedTLS, the SSL package used by requests. This is
because of change in behaviour since version 0.5.3 in MbedTLS, which causes reads and writes to
block.

## Releases and Julia
This package is now registered with Julias package manager. Please only use version 0.1.1 and
higher. Version 0.1.0 contains three serious bugs, which were fixed for 0.1.1.

## Julia 0.7/1.0
Migration to Julia 1.0 is nearly complete. A new release will be available soon.

Before the migration is complete, there is a PR to an upstream package that must be accepted, or I
must configure the dependencies to use a patched version instead of the latest release.

# Contributors
These brave people have contributed to this package:

- @hlaaftana
- @TotalVerb
- @iblis17

## License
DandelionWebSockets is licensed under the MIT license.
