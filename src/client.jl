import Requests: URI

using BufferedStreams
using DandelionWebSockets.Proxy
using DandelionWebSockets.Proxy: stopproxy

mutable struct WebSocketsConnection
    # `logic_proxy` forwards commands to the `ClientProtocol` object, in its own coroutine.
    logic_proxy::Nullable{ClientProtocolProxy}
    # `reader` reads frames from the server.
    reader::Nullable{ServerReader}
    # `rng` is used for random generation of masks when sending frames.
    rng::AbstractRNG
    # `ponger` keeps track of when a pong response is expected from the server.
    ponger::AbstractPonger
    # `pinger` requests that the logic send ping frames to the server at regular intervals.
    pinger::AbstractPinger

    # Requirement
    # @5_3-2-2 Masking uses strong source of entropy
    #
    # This is now handled by seeding the MersenneTwister PRNG with a random UInt32 from the
    # systems entropy.

    WebSocketsConnection() = new(Nullable{ClientProtocolProxy}(),
                                 Nullable{ServerReader}(),
                                 MersenneTwister(rand(RandomDevice(), UInt32)),
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

"Validates a HTTP Upgrade response, and starts all tasks.

Note: As of right now the handshake is not validated, because the response headers aren't set here.
"
function connection_result_(client::WSClient,
                            result::HandshakeResult,
                            handler::WebSocketHandler,
                            fix_small_message_latency::Bool)
    # Requirement
    # @4_1_P5 Waiting for a handshake response
    #
    # Covered by design, as we only get the network socket if and only if the handshake is done.

    # Requirement
    # @4_1_P6 Handshake response is invalid
    #
    # Validation of a HTTP Upgrade to a WebSocket is done by checking the response headers for a key
    # which should contain a computed value.
    if !validate(result)
        println("Could not validate HTTP Upgrade")
        state_closed(handler)
        return false
    end

    if fix_small_message_latency
        ccall(:uv_tcp_nodelay, Cint, (Ptr{Void}, Cint), result.stream, 1)
    end

    connection = get(client.connection)

    # For `writer` the target object is the IO stream for the WebSocket connection.
    writer = WriterProxy(result.stream)

    # Requirement
    # @4_1_8 Handshake response is valid
    state_open(handler)

    # This function stops all the task proxies, effectively cleaning up the WSClient. This is
    # necessary when one wants to reconnect.
    cleanup = () -> begin
        stopproxy(writer)
        stopproxy(handler)
        stopproxy(get(connection.logic_proxy))
        stop(connection.pinger)
        if !isnull(connection.reader)
            stop(get(connection.reader))
        end
    end

    # `ClientProtocol` starts in the `STATE_OPEN` state, because it isn't responsible for making
    # connections. The target object for `logic_proxy` is the `ClientProtocol` object created here.
    framewriter = FrameWriter(writer, connection.rng)
    logic = ClientProtocol(handler, framewriter, connection.ponger, cleanup)
    connection.logic_proxy = Nullable{ClientProtocolProxy}(ClientProtocolProxy(logic))

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
function connection_result_(client::WSClient,
                            result::HandshakeFailure,
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

If your application will send and receive primarily small messages (1448 bytes or smaller), and it
is sensitive to latency, then set `fix_small_message_latency` to true. This sets the TCP_NODELAY
flag, and latency may be improved.
"""
function wsconnect(client::WSClient, uri::URI, handler::WebSocketHandler;
                   fix_small_message_latency=false)
    handler_proxy = WebSocketsHandlerProxy(handler)

    # Requirement
    # @4_1_P1 Initial connection state

    # The first state is always Connecting.
    state_connecting(handler_proxy)

    # This converts from `ws://` or `wss://` to `http://` or `https://`, because that's what
    # Requests.jl expects.
    new_uri = convert_ws_uri(uri)

    client.connection = Nullable{WebSocketsConnection}(WebSocketsConnection())

    # Requirement
    # @4_1_EstablishConnection_3-2 Not using a proxy

    # This makes a HTTP request to the URI and attempts to upgrade the connection to the WebSocket
    # protocol.
    handshake_result = client.do_handshake(get(client.connection).rng, new_uri)

    connection_result_(client, handshake_result, handler_proxy, fix_small_message_latency)
end

# Requirement
# @7_3-2 Clients should not close the WebSocket connection arbitrarily

"Close the WebSocket connection."
stop(c::WSClient) = handle(get(get(c.connection).logic_proxy), CloseRequest())

# Requirement
# @6_1-5 Opcode in the first frame
#
# Covered by design, by `send_text` and `send_binary`.

"Send a single text frame."
send_text(c::WSClient, s::String) = handle(get(get(c.connection).logic_proxy), SendTextFrame(s, true, OPCODE_TEXT))

"Send a single binary frame."
send_binary(c::WSClient, data::Vector{UInt8}) =
    handle(get(get(c.connection).logic_proxy), SendBinaryFrame(data, true, OPCODE_BINARY))

sendmultiframetext(c::WSClient) = TextFrameSender(get(get(c.connection).logic_proxy))
sendmultiframebinary(c::WSClient) = BinaryFrameSender(get(get(c.connection).logic_proxy))
