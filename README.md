# DandelionWebSockets
[![Build Status](https://travis-ci.org/dandeliondeathray/DandelionWebSockets.jl.svg?branch=master)](https://travis-ci.org/dandeliondeathray/DandelionWebSockets.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/7ajck5bv9wxfjxax/branch/master?svg=true)](https://ci.appveyor.com/project/erikedin/dandelionwebsockets-jl/branch/master)

DandelionWebSockets is a client side WebSocket package.

## Usage
Create a subtype of `WebSocketHandler`, with callbacks for WebSocket events. Create a `WSClient` and
connect to a WebSocket server. The type `WebSocketConnection` represents a connection, and is used
to send messages and close the connection. The connection object is supplied in the
`state_connection(::WebSocketHandler, ::WebSocketConnection)` callback, which is always the first
callback.

```julia
using DandelionWebSockets
import DandelionWebSockets: on_text, on_binary
import DandelionWebSockets: state_connecting, state_open,
                            state_closing, state_closed

mutable struct MyHandler <: WebSocketHandler
    # The connection is only available once `state_connecting` has been called.
    connection::Union{WebSocketConnection, Nothing}
end

# These are called when you get a text or binary frame, respectively.
on_text(handler::MyHandler, text::String) = ...
on_binary(handler::MyHandler, data::Vector{UInt8}) = ...

# These are called when the state of the WebSocket changes.
state_connecting(handler::MyHandler, connection::WebSocketConnection) = ...
state_open(handler::MyHandler)       = ...
state_closing(handler::MyHandler)    = ...
state_closed(handler::MyHandler)     = ...
```

The following functions are available on `WebSocketConnection`, to send frames to the server.

```julia
send_text(c::WebSocketConnection, s::String)
send_binary(c::WebSocketConnection, data::Vector{UInt8})

# Close the WebSocket.
stop(c::WebSocketConnection)

# Send a multi-frame text message
textsender = sendmultiframetext(connection)
sendframe(textsender, "Hello")
sendframe(textsender, "world")
sendframe(textsender, "Goodbye."; isfinal=true)

# Send a multi-frame binary message
binarysender = sendmultiframebinary(connection)
sendframe(binarysender, b"Hello")
sendframe(binarysender, b"world")
sendframe(binarysender, b"Goodbye."; isfinal=true)
```

To connect to a WebSocket server, call
`wsconnect(client::WSClient, uri::URI, handler::WebSocketHandler)`.

For the full example code, please check out `examples/echo.jl`.

## Interface changes
Alongside (but unrelated to) the update to Julia 0.7/1.0, the interface has changed some.
Instead of using the `WSClient` type to send messages, a type `WebSocketConnection` is used. This
makes more sense, as a client could (though not supported yet) create several connections. Because
a connection needs a handler, and a handler needs a connection to send messages, the actual
connection object is now supplied in the
`state_connecting(::WebSocketHandler, ::WebSocketConnection)` callback. This will always be the
first callback. Therefore, the connection can be stored in a `Union{WebSocketConnection, Nothing}`
field, and set only after `state_connecting(..)` has been called.

So, in short, change

```julia
struct MyHandler <: WebSocketHandler
    client::WSClient
end

state_connecting(::MyHandler) = ...
```

to

```julia
mutable struct MyHandler <: WebSocketHandler
    connection::Union{WebSocketConnection, Nothing}
end

state_connecting(handler::MyHandler, connection::WebSocketConnection) = handler.connection = connection
```

The sending methods all take a `WebSocketConnection` argument instead of a `WSClient` now.

## Note on I/O and thread safety
Note that print and I/O functions are not thread safe in Julia. Using them in the message and state
callbacks (as is currently done in the examples) may lead to unexpected behaviour, or crashes. See
https://github.com/JuliaLang/julia/issues/17388 for more details.

Thank you to @alessandrousseglioviretta for bringing up this issue.

## Note on SSL
At the moment, SSL is not functioning, due to moving from Requests.jl to HTTP.jl. This is presumably
just a matter of fixing a minor issue, as HTTP.jl does have SSL support.

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
