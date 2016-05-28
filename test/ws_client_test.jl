import DandelionWebSockets: HandshakeResult

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
@mockfunction mock_writer_proxy start(::MockWriterProxy)

@mock MockClientLogicProxy AbstractClientLogicTaskProxy
mock_client_logic_proxy = MockClientLogicProxy()
@mockfunction mock_client_logic_proxy start(::MockClientLogicProxy)

@mock MockHandlerProxy AbstractHandlerProxy
mock_handler_proxy = MockHandlerProxy()
@mockfunction mock_handler_proxy start(::MockHandlerProxy)

facts("WSClient") do
    context("Connecting a WSClient") do
        uri = Requests.URI("http://some/url")

        stream = FakeFrameStream([], Vector{Frame}(), false)
        body = Vector{UInt8}()
        handshake_result = HandshakeResult(
            accept, # This is the accept value we expect, and matches that in the headers dict.
            stream,
            headers,
            body)


        client = WSClient(; do_handshake=handshake, rng=FakeRNG(b"\x00\x00\x00\x00"))

        @expect mocker state_connecting(mocker)
        @expect mocker handshake(rng, uri) handshake_result
        @expect mocker state_open(mocker)

        @expect mock_handler_proxy start(mocker)
        @expect mock_client_logic_proxy start(mock_client_logic_proxy)
        @expect mock_writer_proxy start(mock_writer_proxy)

        attach(client, mocker)
        @fact connect(client, uri;
            client_logic_proxy_factory=x -> mock_client_logic_proxy,
            handler_proxy_factory=x -> mock_handler_proxy,
            writer_proxy_factory=x -> mock_writer_proxy) --> true

        check(mocker)
        check(mock_handler_proxy)
        check(mock_client_logic_proxy)
        check(mock_writer_proxy)
    end

    context("Connection fails") do
        uri = Requests.URI("http://some/url")

        stream = FakeFrameStream([], Vector{Frame}(), false)
        body = Vector{UInt8}()
        handshake_result = HandshakeFailure()


        client = WSClient(; do_handshake=handshake, rng=FakeRNG(b"\x00\x00\x00\x00"))

        @expect mocker state_connecting(mocker)
        @expect mocker handshake(rng, uri) handshake_result
        @expect mocker state_closed(mocker)

        attach(client, mocker)
        @fact connect(client, uri;
            client_logic_proxy_factory=x -> mock_client_logic_proxy,
            handler_proxy_factory=x -> mock_handler_proxy,
            writer_proxy_factory=x -> mock_writer_proxy) --> false

        check(mocker)
        check(mock_handler_proxy)
        check(mock_client_logic_proxy)
        check(mock_writer_proxy)
    end

    context("Connection succeeds, but Accept value is wrong") do
        uri = Requests.URI("http://some/url")

        stream = FakeFrameStream([], Vector{Frame}(), false)
        body = Vector{UInt8}()
        handshake_result = HandshakeResult(
            "thisisthewrongacceptvalue",
            stream,
            headers,
            body)


        client = WSClient(; do_handshake=handshake, rng=FakeRNG(b"\x00\x00\x00\x00"))

        @expect mocker state_connecting(mocker)
        @expect mocker handshake(rng, uri) handshake_result
        @expect mocker state_closed(mocker)

        attach(client, mocker)
        @fact connect(client, uri;
            client_logic_proxy_factory=x -> mock_client_logic_proxy,
            handler_proxy_factory=x -> mocker,
            writer_proxy_factory=x -> mock_writer_proxy) --> false

        check(mocker)
        check(mock_handler_proxy)
        check(mock_client_logic_proxy)
        check(mock_writer_proxy)
    end
end