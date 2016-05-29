import DandelionWebSockets: HandshakeResult, HandshakeFailure,
    AbstractServerReader, start_reader, stop, attach, start

@mock Mocker WebSocketHandler
mocker = Mocker()

@mockfunction mocker handshake(::AbstractRNG, ::Requests.URI)
@mockfunction(mocker,
    on_text(::Mocker, ::UTF8String),
    on_binary(::Mocker, ::Vector{UInt8}),
    state_connecting(::Mocker),
    state_open(::Mocker),
    state_closing(::Mocker),
    state_closed(::Mocker))

@mock MockWriterProxy AbstractWriterTaskProxy
mock_writer_proxy = MockWriterProxy()
@mockfunction mock_writer_proxy start(::MockWriterProxy) attach(::MockWriterProxy, ::IO)

@mock MockClientLogicProxy AbstractClientTaskProxy
mock_client_logic_proxy = MockClientLogicProxy()
@mockfunction(mock_client_logic_proxy,
    start(::MockClientLogicProxy),
    attach(::MockClientLogicProxy, ::AbstractClientLogic))

@mock MockHandlerProxy AbstractHandlerTaskProxy
mock_handler_proxy = MockHandlerProxy()
@mockfunction(mock_handler_proxy,
    start(::MockHandlerProxy),
    attach(::MockHandlerProxy, ::WebSocketHandler),
    state_open(::MockHandlerProxy),
    state_closed(::MockHandlerProxy))

@mock MockServerReader AbstractServerReader
mock_server_reader = MockServerReader()
@mockfunction(mock_server_reader,
    start_reader(::IO, ::MockClientLogicProxy),
    stop(::MockServerReader))

accept_field = ascii("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
headers = Dict(
    # This is the expected response when the client sends
    # Sec-WebSocket-Key => "dGhlIHNhbXBsZSBub25jZQ=="
    "Sec-WebSocket-Accept" => accept_field
)
fake_rng = FakeRNG{UInt8}(b"\x00\x00\x00\x00")
facts("WSClient") do
    context("Connecting a WSClient") do
        uri = Requests.URI("http://some/url")

        stream = FakeFrameStream(Vector{Frame}(), Vector{Frame}(), false)
        body = Vector{UInt8}()
        handshake_result = HandshakeResult(
            accept_field, # This is the accept value we expect, and matches that in the headers dict.
            stream,
            headers,
            body)

        client = WSClient(;
            do_handshake=handshake,
            rng=fake_rng,
            writer=mock_writer_proxy,
            handler_proxy=mock_handler_proxy,
            logic_proxy=mock_client_logic_proxy)

        @expect mocker state_connecting(mocker)
        @expect mocker handshake(fake_rng, uri) handshake_result


        @expect mock_handler_proxy attach(mock_handler_proxy, mocker)
        @expect mock_handler_proxy start(mock_handler_proxy)
        @expect mock_handler_proxy state_open(mock_handler_proxy)

        @expect mock_client_logic_proxy attach(mock_client_logic_proxy, TypeMatcher(AbstractClientLogic))
        @expect mock_client_logic_proxy start(mock_client_logic_proxy)

        @expect mock_writer_proxy attach(mock_writer_proxy, stream)
        @expect mock_writer_proxy start(mock_writer_proxy)

        @expect mock_server_reader start_reader(TypeMatcher(IO), mock_client_logic_proxy)

        @fact wsconnect(client, uri, mocker) --> true

        check(mocker)
        check(mock_handler_proxy)
        check(mock_client_logic_proxy)
        check(mock_writer_proxy)
        check(mock_server_reader)
    end

    context("Connection fails") do
        uri = Requests.URI("http://some/url")

        stream = FakeFrameStream(Vector{Frame}(), Vector{Frame}(), false)
        body = Vector{UInt8}()
        handshake_result = HandshakeFailure()


        client = WSClient(;
            do_handshake=handshake,
            rng=fake_rng,
            writer=mock_writer_proxy,
            handler_proxy=mock_handler_proxy,
            logic_proxy=mock_client_logic_proxy)

        @expect mocker state_connecting(mocker)
        @expect mocker handshake(fake_rng, uri) handshake_result
        @expect mocker state_closed(mocker)

        @fact wsconnect(client, uri, mocker) --> false

        check(mocker)
        check(mock_handler_proxy)
        check(mock_client_logic_proxy)
        check(mock_writer_proxy)
        check(mock_server_reader)
    end

    context("Connection succeeds, but Accept value is wrong") do
        uri = Requests.URI("http://some/url")

        stream = FakeFrameStream(Vector{Frame}(), Vector{Frame}(), false)
        body = Vector{UInt8}()
        handshake_result = HandshakeResult(
            "thisisthewrongacceptvalue",
            stream,
            headers,
            body)


        client = WSClient(;
            do_handshake=handshake,
            rng=fake_rng,
            writer=mock_writer_proxy,
            handler_proxy=mock_handler_proxy,
            logic_proxy=mock_client_logic_proxy)

        @expect mocker state_connecting(mocker)
        @expect mocker handshake(fake_rng, uri) handshake_result
        @expect mocker state_closed(mocker)

        @fact wsconnect(client, uri, mocker) --> false

        check(mocker)
        check(mock_handler_proxy)
        check(mock_client_logic_proxy)
        check(mock_writer_proxy)
        check(mock_server_reader)
    end
end