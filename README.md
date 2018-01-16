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

```
send_text(c::WSClient, s::String)
send_binary(c::WSClient, data::Vector{UInt8})

# Close the WebSocket.
stop(c::WSClient)
```

To connect to a WebSocket server, call
`wsconnect(client::WSClient, uri::URI, handler::WebSocketHandler)`.

For the full example code, please check out `examples/echo.jl`.

## Note on I/O and thread safety
Note that print and I/O functions are not thread safe in Julia. Using them in the message and state
callbacks (as is currently done in the examples) may lead to unexpected behaviour, or crashes. See
https://github.com/JuliaLang/julia/issues/17388 for more details.

Thank you to @alessandrousseglioviretta for bringing up this issue.

## Releases and Julia
If you use Julia 0.6, use master for the time being. I intend to register this
package with a proper version, soon. The package will not remain compatible with
Julia prior to 0.6.

## Needs work

- Implement regular pings, to ensure the connection is up.
- Ability to send multi-frame messages.
- Verify functionality with current Requests.jl release.

# Contributors
These brave people have contributed to this package:

- @hlaaftana
- @TotalVerb
- @iblis17

## License
DandelionWebSockets is licensed under the MIT license.
