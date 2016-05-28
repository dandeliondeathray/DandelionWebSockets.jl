import Requests: URI


immutable WSClient <: AbstractWSClient
    writer::WriterTaskProxy
    handler_proxy::HandlerTaskProxy
    logic_proxy::ClientLogicTaskProxy
    reader::ServerReader

    function WSClient(;do_handshake=DandelionWebSockets.do_handshake,
                       rng::AbstractRNG=MersenneTwister())
        rng = MersenneTwister()
        # Requests expect a HTTP/HTTPS scheme, so we convert from the ws/wss to http/https,
        # if necessary.
        new_uri = convert_ws_uri(uri)
        handshake_result = do_handshake(rng, new_uri)

        writer = WriterTaskProxy(handshake_result.stream)
        start(writer)

        handler_proxy = HandlerTaskProxy(handler)
        start(handler_proxy)

        logic = ClientLogic(STATE_OPEN, handler_proxy, writer, rng)
        logic_proxy = ClientLogicTaskProxy(logic)
        start(logic_proxy)

        reader = start_reader(handshake_result.stream, logic_proxy)

        c = new(writer, handler_proxy, logic_proxy, reader)
        on_create(handler, c)
        c
    end
end

function connection_result_(result::HandshakeResult, handler::WebSocketHandler)
    state_open(handler)
    true
end

function connection_result_(result::HandshakeFailure, handler::WebSocketHandler)
    state_closed(handler)
    false
end


function connect(client::WSClient, uri::URI)
    handshake_result = client.do_handshake()
    connection_result_(handshake_result)
end
