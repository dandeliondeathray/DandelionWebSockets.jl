import Requests: URI
import Base: show
using BufferedStreams

# These proxies glue the different coroutines together. For isntance, `ClientLogic` calls callback
# function such as `on_text` and `state_closing` on the proxy, which is then called on the callback
# object by another coroutine. This lets the logic run independently of the callbacks.
@taskproxy(HandlerTaskProxy, AbstractHandlerTaskProxy, WebSocketHandler,
    on_text, on_binary,
    state_connecting, state_open, state_closing, state_closed)

@taskproxy ClientLogicTaskProxy AbstractClientTaskProxy AbstractClientLogic handle
@taskproxy WriterTaskProxy AbstractWriterTaskProxy IO write

"""
A WebSocket client, used to connect to a server, and send messages.

Note: The keyword arguments in the constructor are primarily for testing.
"""
type WSClient <: AbstractWSClient
    # `writer` writes frames to the socket.
    writer::AbstractWriterTaskProxy
    # `handler_proxy` does the callbacks, in its own coroutine.
    handler_proxy::AbstractHandlerTaskProxy
    # `logic_proxy` forwards commands to the `ClientLogic` object, in its own coroutine.
    logic_proxy::AbstractClientTaskProxy
    # `reader` reads frames from the server.
    reader::Nullable{ServerReader}
    # `do_handshake` is a function that performs a HTTP Upgrade to a WebSocket connection.
    do_handshake::Function
    # `rng` is used for random generation of masks when sending frames.
    rng::AbstractRNG
    # `ponger` keeps track of when a pong response is expected from the server.
    ponger::AbstractPonger
    # `pinger` requests that the logic send ping frames to the server at regular intervals.
    pinger::AbstractPinger

    function WSClient(;
                      do_handshake=DandelionWebSockets.do_handshake,
                      rng::AbstractRNG=MersenneTwister(),
                      writer::AbstractWriterTaskProxy=WriterTaskProxy(),
                      handler_proxy::AbstractHandlerTaskProxy=HandlerTaskProxy(),
                      logic_proxy::AbstractClientTaskProxy=ClientLogicTaskProxy(),
                      ponger::AbstractPonger=Ponger(2.0),
                      pinger::AbstractPinger=Pinger(5.0))
        new(writer, handler_proxy, logic_proxy, Nullable{ServerReader}(), do_handshake, rng, ponger, pinger)
    end
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

    # For `writer` the target object is the IO stream for the WebSocket connection.
    attach(client.writer, result.stream)
    start(client.writer)

    # For `handler_proxy` the target is the handler object on which callbacks should be made.
    attach(client.handler_proxy, handler)
    start(client.handler_proxy)

    # Note: This doesn't directly call the `state_open` callback on the handler, but rather enqueues
    # the function call, so that the `handler_proxy` coroutine will make the actual callback.
    state_open(client.handler_proxy)

    # This function stops all the task proxies, effectively cleaning up the WSClient. This is
    # necessary when one wants to reconnect.
    cleanup = () -> begin
        stop(client.writer)
        stop(client.handler_proxy)
        stop(client.logic_proxy)
        stop(client.pinger)
        if !isnull(client.reader)
            stop(get(client.reader))
        end
    end

    # `ClientLogic` starts in the `STATE_OPEN` state, because it isn't responsible for making
    # connections. The target object for `logic_proxy` is the `ClientLogic` object created here.
    logic = ClientLogic(STATE_OPEN, client.handler_proxy, client.writer, client.rng, client.ponger,
                        cleanup)
    attach(client.logic_proxy, logic)
    start(client.logic_proxy)

    # `Ponger` requires a logic object it can alert when a pong request hasn't been received within
    # the expected time frame. This attaches that logic object to the ponger.
    attach(client.ponger, client.logic_proxy)

    # `Pinger` sends ping requests at regular intervals.
    attach(client.pinger, client.logic_proxy)

    # The target for `reader` is the same stream we're writing to.
    client.reader = Nullable{ServerReader}(
        start_reader(result.stream, client.logic_proxy))
    true
end

"The HTTP Upgrade failed, for whatever reason."
function connection_result_(client::WSClient, result::HandshakeFailure, handler::WebSocketHandler)
    # Calling `state_closed` here, because that's where we're expected to attempt to reconnect.
    # Note: We call `state_closed` directly, not using the proxy, because the proxy hasn't been
    # started yet.
    state_closed(handler)
    false
end

"Connect the client to a WebSocket server at `uri`, and use `handler` for the callbacks."
function wsconnect(client::WSClient, uri::URI, handler::WebSocketHandler)
    # Note: Calling the `state_connecting` callback directly, because the `handler_proxy` hasn't
    # been started yet.
    state_connecting(handler)

    # This converts from `ws://` or `wss://` to `http://` or `https://`, because that's what
    # Requests.jl expects.
    new_uri = convert_ws_uri(uri)

    # This makes a HTTP request to the URI and attempts to upgrade the connection to the WebSocket
    # protocol.
    handshake_result = client.do_handshake(client.rng, new_uri)

    connection_result_(client, handshake_result, handler)
end

"Close the WebSocket connection."
stop(c::WSClient) = handle(c.logic_proxy, CloseRequest())

"Send a single text frame."
send_text(c::WSClient, s::UTF8String) = handle(c.logic_proxy, SendTextFrame(s, true, OPCODE_TEXT))

"Send a single binary frame."
send_binary(c::WSClient, data::Vector{UInt8}) =
    handle(c.logic_proxy, SendBinaryFrame(data, true, OPCODE_BINARY))