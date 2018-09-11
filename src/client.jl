using DandelionWebSockets.Proxy
using DandelionWebSockets.Proxy: stopproxy

mutable struct WebSocketConnectionImpl <: WebSocketConnection
    # `logic_proxy` forwards commands to the `ClientProtocol` object, in its own coroutine.
    logic_proxy::Union{ClientProtocolProxy, Nothing}
    # `reader` reads frames from the server.
    reader::Union{ServerReader, Nothing}
    # `rng` is used for random generation of masks when sending frames.
    rng::AbstractRNG
    # `ponger` keeps track of when a pong response is expected from the server.
    ponger::AbstractPonger
    # `pinger` requests that the logic send ping frames to the server at regular intervals.
    pinger::AbstractPinger

    # Requirement
    # @5_3-2-2 Masking uses strong source of entropy
    #
    # This is now handled by `RandomDevice`.

    WebSocketConnectionImpl() = new(nothing,
                                    nothing,
                                    RandomDevice(),
                                    Ponger(3.0, misses=3),
                                    Pinger(5.0))
end

"""
A WebSocket client, used to connect to a server, and send messages.

Note: The keyword arguments in the constructor are primarily for testing.
"""
mutable struct WSClient <: AbstractWSClient
    # WebSocketConnection maintains the state for a single connection.
    connection::Union{WebSocketConnection, Nothing}
    # `do_handshake` is a function that performs a HTTP Upgrade to a WebSocket connection.
    handshake::WebSocketHandshake

    WSClient(; handshake::WebSocketHandshake = HTTPHandshake(RandomDevice(), HTTPjlAdapter())) = 
        new(nothing, handshake)
end

"""
    tcpnodelay(::IO)

Sets the TCP_NODELAY flag on a socket. This is a separate function only for testing purposes. It
can be implemented with a more specific type if the flag makes no sense for another `IO` subtype.
"""
tcpnodelay(io::IO) = ccall(:uv_tcp_nodelay, Cint, (Ptr{Nothing}, Cint), io, 1)

"""
    connection_result(::WSClient, ::GoodHandshake, ::WebSocketHandler, fix_small_message_latency::Bool)

For a valid handshake, start all background tasks for this connection. This includes tasks for
reading and writing from the socket, as well as a task for user callback.
"""
function connection_result_(client::WSClient,
                            result::GoodHandshake,
                            handler::WebSocketHandler,
                            fix_small_message_latency::Bool)
    # Requirement
    # @4_1_P5 Waiting for a handshake response
    #
    # Covered by design, as we only get the network socket if and only if the handshake is done.

    if fix_small_message_latency
        tcpnodelay(result.io)
    end

    connection = client.connection

    # For `writer` the target object is the IO stream for the WebSocket connection.
    writer = WriterProxy(result.io)

    # Requirement
    # @4_1_8 Handshake response is valid
    state_open(handler)

    # This function stops all the task proxies, effectively cleaning up the WSClient. This is
    # necessary when one wants to reconnect.
    cleanup = () -> begin
        stopproxy(writer)
        stopproxy(handler)
        stopproxy(connection.logic_proxy)
        stop(connection.pinger)
        if connection.reader != nothing
            stop(connection.reader)
        end
    end

    # `ClientProtocol` starts in the `STATE_OPEN` state, because it isn't responsible for making
    # connections. The target object for `logic_proxy` is the `ClientProtocol` object created here.
    framewriter = FrameWriter(writer, connection.rng)
    logic = ClientProtocol(handler, framewriter, connection.ponger, cleanup)
    connection.logic_proxy = ClientProtocolProxy(logic)

    # `Ponger` requires a logic object it can alert when a pong request hasn't been received within
    # the expected time frame. This attaches that logic object to the ponger.
    attach(connection.ponger, connection.logic_proxy)

    # `Pinger` sends ping requests at regular intervals.
    attach(connection.pinger, connection.logic_proxy)

    # The target for `reader` is the same stream we're writing to.
    connection.reader = start_reader(result.io, connection.logic_proxy)
    true
end

"The HTTP Upgrade failed, for whatever reason."
function connection_result_(client::WSClient,
                            result::BadHandshake,
                            handler::WebSocketHandler,
                            fix_small_message_latency::Bool)
    # Requirement
    # @4_1_EstablishConnection_4   Could not open the connection
    # @4_1_EstablishConnection_5-2 TLS Connection fails

    # Calling `state_closed` here, because that's where we're expected to attempt to reconnect.
    state_closed(handler)
    false
end

"""
Connect the client to a WebSocket server at `uri`, and use `handler` for the callbacks.

# Arguments
- `fix_small_message_latency::Bool = false`: Set the TCP_NODELAY flag to improve small message latency.

# Fix small message latency
The TCP protocol can buffer small messages (1448 bytes and smaller). The reason is that this reduces
the overhead when sending large amounts of small packets. However, it also means that latency can be
much higher for small messages. This buffering can be disabled by setting a flag TCP_NODELAY.
By default, the WebSocket client will now set the TCP_NODELAY flag.

If your application will send and receive primarily small messages (1448 bytes or smaller), and it
is sensitive to latency, then leave `fix_small_message_latency` set to true (now the default).
This sets the TCP_NODELAY flag. If you are not concerned about latency, but concerned about
throughput for many small messages, then you can set `fix_small_message_latency = false`. Then you
may get higher throughput, at the expense of higher latency for small messages.
"""
function wsconnect(client::WSClient, uri::String, handler::WebSocketHandler;
                   fix_small_message_latency=true)
    handler_proxy = WebSocketsHandlerProxy(handler)

    # Requirement
    # @4_1_P1 Initial connection state

    client.connection = WebSocketConnectionImpl()

    # The first state is always Connecting.
    state_connecting(handler_proxy, client.connection)


    # Requirement
    # @4_1_EstablishConnection_3-2 Not using a proxy

    # This makes a HTTP request to the URI and attempts to upgrade the connection to the WebSocket
    # protocol.
    handshake_result = performhandshake(client.handshake, uri)
    connection_result_(client, handshake_result, handler_proxy, fix_small_message_latency)
end

# Requirement
# @7_3-2 Clients should not close the WebSocket connection arbitrarily

"Close the WebSocket connection."
function stop(connection::WebSocketConnection)
    if connection.logic_proxy != nothing
        handle(connection.logic_proxy, CloseRequest())
    end
end

# Requirement
# @6_1-5 Opcode in the first frame
#
# Covered by design, by `send_text` and `send_binary`.

"Send a single text frame."
send_text(connection::WebSocketConnection, s::String) = handle(connection.logic_proxy, SendTextFrame(s, true, OPCODE_TEXT))

"Send a single binary frame."
send_binary(connection::WebSocketConnection, data::AbstractVector{UInt8}) =
    handle(connection.logic_proxy, SendBinaryFrame(data, true, OPCODE_BINARY))

sendmultiframetext(connection::WebSocketConnection) = TextFrameSender(connection.logic_proxy)
sendmultiframebinary(connection::WebSocketConnection) = BinaryFrameSender(connection.logic_proxy)
