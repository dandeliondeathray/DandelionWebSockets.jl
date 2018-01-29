import Base: show

import Requests: URI

using BufferedStreams
using DandelionWebSockets.Proxy
using DandelionWebSockets.Proxy: stopproxy

# These proxies glue the different coroutines together. For isntance, `ClientLogic` calls callback
# function such as `on_text` and `state_closing` on the proxy, which is then called on the callback
# object by another coroutine. This lets the logic run independently of the callbacks.
@taskproxy WriterTaskProxy AbstractWriterTaskProxy IO write

mutable struct WebSocketsConnection
    # `writer` writes frames to the socket.
    writer::AbstractWriterTaskProxy
    # `logic_proxy` forwards commands to the `ClientLogic` object, in its own coroutine.
    logic_proxy::Nullable{ClientLogicProxy}
    # `reader` reads frames from the server.
    reader::Nullable{ServerReader}
    # handler receives the users callbacks.
    handler::WebSocketsHandlerProxy
    # `rng` is used for random generation of masks when sending frames.
    rng::AbstractRNG
    # `ponger` keeps track of when a pong response is expected from the server.
    ponger::AbstractPonger
    # `pinger` requests that the logic send ping frames to the server at regular intervals.
    pinger::AbstractPinger

    WebSocketsConnection(handler::WebSocketsHandlerProxy) = new(WriterTaskProxy(),
                                                                Nullable{ClientLogicProxy}(),
                                                                Nullable{ServerReader}(),
                                                                handler,
                                                                MersenneTwister(0),
                                                                Ponger(3.0, misses=3),
                                                                Pinger(5.0))
end

"""
A WebSocket client, used to connect to a server, and send messages.

Note: The keyword arguments in the constructor are primarily for testing.
"""
mutable struct WSClient <: AbstractWSClient
    # WebSocketsConnection maintains the state for a single connection.
    connection::Nullable{WebSocketsConnection}
    # `do_handshake` is a function that performs a HTTP Upgrade to a WebSocket connection.
    do_handshake::Function

    WSClient(; do_handshake=DandelionWebSockets.do_handshake) = new(Nullable{WebSocketsConnection}(), do_handshake)
end
show(io::IO, c::WSClient) =
    show(io, "WSClient($(c.handler_proxy), $(c.logic_proxy))")

"Validates a HTTP Upgrade response, and starts all tasks.

Note: As of right now the handshake is not validated, because the response headers aren't set here.
"
function connection_result_(client::WSClient, result::HandshakeResult, handler::WebSocketHandler)
    # Validation of a HTTP Upgrade to a WebSocket is done by checking the response headers for a key
    # which should contain a computed value.
    if !validate(result)
        println("Could not validate HTTP Upgrade")
        state_closed(handler)
        return false
    end

    # Each `TaskProxy` used here acts as a proxy for another object. When you call some predefined
    # functions on a proxy, it takes the function and arguments and puts them on a channel. A
    # coroutine takes there function/arguments from the channel and calls the same function, but on
    # the target object it acts as a proxy for. This is because we want some parts to work
    # concurrently with others
    # Calling `attach` on a proxy sets the target object.
    # Calling `start` on a proxy starts the coroutine that calls functions on that target.

    connection = get(client.connection)

    # For `writer` the target object is the IO stream for the WebSocket connection.
    attach(connection.writer, result.stream)
    start(connection.writer)

    state_open(handler)

    # This function stops all the task proxies, effectively cleaning up the WSClient. This is
    # necessary when one wants to reconnect.
    cleanup = () -> begin
        stop(connection.writer)
        stopproxy(connection.handler)
        stop(connection.pinger)
        if !isnull(connection.reader)
            stop(get(connection.reader))
        end
    end

    # `ClientLogic` starts in the `STATE_OPEN` state, because it isn't responsible for making
    # connections. The target object for `logic_proxy` is the `ClientLogic` object created here.
    logic = ClientLogic(STATE_OPEN, connection.handler, connection.writer, connection.rng, connection.ponger,
                        cleanup)
    connection.logic_proxy = Nullable{ClientLogicProxy}(ClientLogicProxy(logic))

    # `Ponger` requires a logic object it can alert when a pong request hasn't been received within
    # the expected time frame. This attaches that logic object to the ponger.
    attach(connection.ponger, get(connection.logic_proxy))

    # `Pinger` sends ping requests at regular intervals.
    attach(connection.pinger, get(connection.logic_proxy))

    # The target for `reader` is the same stream we're writing to.
    connection.reader = Nullable{ServerReader}(
        start_reader(result.stream, get(connection.logic_proxy)))
    true
end

"The HTTP Upgrade failed, for whatever reason."
function connection_result_(client::WSClient, result::HandshakeFailure, handler::WebSocketHandler)
    # Calling `state_closed` here, because that's where we're expected to attempt to reconnect.
    state_closed(handler)
    false
end

"Connect the client to a WebSocket server at `uri`, and use `handler` for the callbacks."
function wsconnect(client::WSClient, uri::URI, handler::WebSocketHandler)
    handler_proxy = WebSocketsHandlerProxy(handler)

    # The first state is always Connecting.
    state_connecting(handler_proxy)

    # This converts from `ws://` or `wss://` to `http://` or `https://`, because that's what
    # Requests.jl expects.
    new_uri = convert_ws_uri(uri)

    client.connection = Nullable{WebSocketsConnection}(WebSocketsConnection(handler_proxy))

    # This makes a HTTP request to the URI and attempts to upgrade the connection to the WebSocket
    # protocol.
    handshake_result = client.do_handshake(get(client.connection).rng, new_uri)

    connection_result_(client, handshake_result, handler_proxy)
end

"Close the WebSocket connection."
stop(c::WSClient) = handle(get(get(c.connection).logic_proxy), CloseRequest())

"Send a single text frame."
send_text(c::WSClient, s::String) = handle(get(get(c.connection).logic_proxy), SendTextFrame(s, true, OPCODE_TEXT))

"Send a single binary frame."
send_binary(c::WSClient, data::Vector{UInt8}) =
    handle(get(get(c.connection).logic_proxy), SendBinaryFrame(data, true, OPCODE_BINARY))
