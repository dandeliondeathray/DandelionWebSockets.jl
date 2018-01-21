import DandelionWebSockets: AbstractPonger, pong_received, attach, ClientPingRequest,
                            FrameFromServer, SendTextFrame, ping_sent

struct LogicTestCase
	description::AbstractString
	initial_state::DandelionWebSockets.SocketState
	rng::FakeRNG{UInt8}
	#frames::Dict{AbstractString, Frame}
	input::Vector{Any} # This will contain types such as FrameFromServer or SendTextFrame
	handler_calls::Vector{Any}
	writer_calls::Vector{Any}
	final_state::DandelionWebSockets.SocketState
	client_cleanup_called::Int
end

function LogicTestCase(;
	description="",
	initial_state=DandelionWebSockets.STATE_CONNECTING,
	rng=FakeRNG(UInt8),
	input=[],
	handler_calls=[],
	writer_calls=[],
	final_state=initial_state,
	client_cleanup_called=0)

	LogicTestCase(description, initial_state, rng, input, handler_calls, writer_calls, final_state, client_cleanup_called)
end


mock_handler = MockHandlerTaskProxy()
@mockfunction(mock_handler,
    on_text(::MockHandlerTaskProxy, ::String),
    on_binary(::MockHandlerTaskProxy, ::Vector{UInt8}),
    state_connecting(::MockHandlerTaskProxy),
    state_open(::MockHandlerTaskProxy),
    state_closing(::MockHandlerTaskProxy),
    state_closed(::MockHandlerTaskProxy))

mock_writer = MockWriterTaskProxy()
@mockfunction(mock_writer, write(::MockWriterTaskProxy, ::Frame))

@mock MockPonger AbstractPonger
mock_ponger = MockPonger()
@mockfunction mock_ponger pong_received(::MockPonger) attach(::MockPonger, ::AbstractClientTaskProxy) ping_sent(::MockPonger)

logic_tests = [

	#
	# Server to client tests
	#

	LogicTestCase(
		description    = "Buffer is cleared between two separate multi-fragment messages",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(UInt8),
		input          = [FrameFromServer(test_frame2),
		                  FrameFromServer(test_frame3),
		                  FrameFromServer(test_frame2),
		                  FrameFromServer(test_frame3)],
		handler_calls  = [:(@expect mock_handler on_text(mock_handler, "Hello")),
		                  :(@expect mock_handler on_text(mock_handler, "Hello"))],
		writer_calls   = []),

	LogicTestCase(
		description    = "A ping request is received between two fragments",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(mask),
		input          = [FrameFromServer(test_frame2),
						  FrameFromServer(server_ping_frame),
		                  FrameFromServer(test_frame3)],
		handler_calls  = [:(@expect mock_handler on_text(mock_handler, "Hello"))],
		writer_calls   = [:(@expect mock_writer write(mock_writer, client_pong_frame))]),

	LogicTestCase(
		description    = "A pong response has the same payload as the ping",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(mask),
		input          = [FrameFromServer(server_ping_frame_w_pay)],
		handler_calls  = [],
		writer_calls   = [:(@expect mock_writer write(mock_writer, client_pong_frame_w_pay))]),


	LogicTestCase(
		description    = "A binary message from the server is received",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(b""),
		input          = [FrameFromServer(frame_bin_1)],
		handler_calls  = [:(@expect mock_handler on_binary(mock_handler, b"Hello"))],
		writer_calls   = []),

	LogicTestCase(
		description    = "Two binary fragments are received from the server",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(UInt8),
		input          = [FrameFromServer(frame_bin_start),
		                  FrameFromServer(frame_bin_final)],
		handler_calls  = [:(@expect mock_handler on_binary(mock_handler, b"Hello"))],
		writer_calls   = []),

	LogicTestCase(
		description    = "Pong responses are propagated to Ponger",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(UInt8),
		input          = [FrameFromServer(server_pong_frame)],
		handler_calls  = [:(@expect mock_ponger pong_received(mock_ponger))],
		writer_calls   = []),


	#
	# Client to server tests
	#

	LogicTestCase(
		description    = "Client sends a message",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(mask),
		input          = [SendTextFrame("Hello", true, OPCODE_TEXT)],
		handler_calls  = [],
		writer_calls   = [:(@expect mock_writer write(mock_writer, test_frame4))]),

	LogicTestCase(
		description    = "Client sends a binary message",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(mask),
		input          = [DandelionWebSockets.SendBinaryFrame(b"Hello", true, OPCODE_BINARY)],
		handler_calls  = [],
		writer_calls   = [:(@expect mock_writer write(mock_writer, test_bin_frame4))]),

	LogicTestCase(
		description    = "Client sends a binary message, 256 bytes",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(mask),
		input          = [DandelionWebSockets.SendBinaryFrame(zero256, true, OPCODE_BINARY)],
		handler_calls  = [],
		writer_calls   = [:(@expect mock_writer write(mock_writer, test_bin_frame_256))]),

	LogicTestCase(
		description    = "Client sends a binary message, 65k",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(mask),
		input          = [DandelionWebSockets.SendBinaryFrame(zero65k, true, OPCODE_BINARY)],
		handler_calls  = [],
		writer_calls   = [:(@expect mock_writer write(mock_writer, test_bin_frame_65k))]),


	LogicTestCase(
		description    = "Client sends two fragments",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(vcat(mask, mask2)),
		input          = [SendTextFrame("Hel", false, OPCODE_TEXT),
		                  SendTextFrame("lo", true, OPCODE_CONTINUATION)],
		handler_calls  = [],
		writer_calls   = [:(@expect mock_writer write(mock_writer, test_frame5)),
		                  :(@expect mock_writer write(mock_writer, test_frame6))]),

	LogicTestCase(
		description    = "Frames are not sent when in CLOSING",
		initial_state  = DandelionWebSockets.STATE_CLOSING,
		rng            = FakeRNG(UInt8),
		input          = [SendTextFrame("Hello", true, OPCODE_TEXT),
						  SendTextFrame("Hel", false, OPCODE_TEXT),
		                  SendTextFrame("lo", true, OPCODE_CONTINUATION)],
		handler_calls  = [],
		writer_calls   = []),

	LogicTestCase(
		description    = "Frames are not sent when in CONNECTING",
		initial_state  = DandelionWebSockets.STATE_CONNECTING,
		rng            = FakeRNG(UInt8),
		input          = [SendTextFrame("Hello", true, OPCODE_TEXT),
						  SendTextFrame("Hel", false, OPCODE_TEXT),
		                  SendTextFrame("lo", true, OPCODE_CONTINUATION)],
		handler_calls  = [],
		writer_calls   = []),

	LogicTestCase(
		description    = "Frames are not sent when in CLOSED",
		initial_state  = DandelionWebSockets.STATE_CLOSED,
		rng            = FakeRNG(UInt8),
		input          = [SendTextFrame("Hello", true, OPCODE_TEXT),
						  SendTextFrame("Hel", false, OPCODE_TEXT),
		                  SendTextFrame("lo", true, OPCODE_CONTINUATION)],
		handler_calls  = [],
		writer_calls   = []),

	LogicTestCase(
		description    = "Sending a ping request to the server",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(mask),
		input          = [ClientPingRequest()],
		handler_calls  = [:(@expect mock_ponger ping_sent(mock_ponger))],
		writer_calls   = [:(@expect mock_writer write(mock_writer, client_ping_frame))]),

	LogicTestCase(
		description    = "Pings are not sent in non-open states.",
		initial_state  = DandelionWebSockets.STATE_CLOSED,
		rng            = FakeRNG(UInt8),
		input          = [ClientPingRequest()],
		handler_calls  = [],
		writer_calls   = []),


	#
	# Closing the connection
	#

	LogicTestCase(
		description    = "The server initiates a closing handshake.",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(mask),
		input          = [FrameFromServer(server_close_frame)],
		handler_calls  = [:(@expect mock_handler state_closing(mock_handler))],
		writer_calls   = [:(@expect mock_writer write(mock_writer, client_close_reply))],
		final_state    = DandelionWebSockets.STATE_CLOSING_SOCKET),

	LogicTestCase(
		description    = "The client initiates a closing handshake.",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG{UInt8}(mask),
		input          = [DandelionWebSockets.CloseRequest()],
		handler_calls  = [:(@expect mock_handler state_closing(mock_handler))],
		writer_calls   = [:(@expect mock_writer write(mock_writer, client_close_reply))],
		final_state    = DandelionWebSockets.STATE_CLOSING),

	LogicTestCase(
		description    = "The server replies to a client initiated handshake",
		initial_state  = DandelionWebSockets.STATE_CLOSING,
		rng            = FakeRNG(UInt8),
		input          = [FrameFromServer(server_close_frame)],
		handler_calls  = [],
		writer_calls   = [],
		final_state    = DandelionWebSockets.STATE_CLOSING_SOCKET),

	LogicTestCase(
		description    = "The socket is closed cleanly",
		initial_state  = DandelionWebSockets.STATE_CLOSING_SOCKET,
		rng            = FakeRNG(UInt8),
		input          = [DandelionWebSockets.SocketClosed()],
		handler_calls  = [:(@expect(mock_handler, state_closed(mock_handler)))],
		writer_calls   = [],
		final_state    = DandelionWebSockets.STATE_CLOSED,
		client_cleanup_called = 1),

	LogicTestCase(
		description    = "Close connection on a missing ping",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(UInt8),
		input          = [PongMissed()],
		handler_calls  = [:(@expect(mock_handler, state_closed(mock_handler)))],
		writer_calls   = [],
		final_state    = DandelionWebSockets.STATE_CLOSED,
		client_cleanup_called = 1),

]


facts("ClientLogic") do
	#
	# Declarative tests
	#

	for test in logic_tests
		context(test.description) do
			#mock_handler = MockHandlerTaskProxy(test.handler_calls)
			#mock_writer  = MockWriterTaskProxy(test.writer_calls)
			client_cleanup_called = 0
			client_cleanup = () -> client_cleanup_called += 1

			logic = ClientLogic(test.initial_state,
				                mock_handler,
				                mock_writer,
				                test.rng,
				                mock_ponger,
				                client_cleanup)

			for call in test.handler_calls
				eval(call)
			end
			for call in test.writer_calls
				eval(call)
			end

			for x in test.input
				DandelionWebSockets.handle(logic, x)
			end

			@fact logic.state --> test.final_state
			@fact client_cleanup_called --> test.client_cleanup_called

			check(mock_handler)
			check(mock_writer)
			check(mock_ponger)
		end
	end


	#
	# Utilities
	#

	context("Masking") do
		hello = b"Hello"
		hel   = b"Hel"
		masked_hello = b"\x7f\x9f\x4d\x51\x58"

		DandelionWebSockets.masking!(hello, mask)
		@fact hello --> b"\x7f\x9f\x4d\x51\x58"

		DandelionWebSockets.masking!(masked_hello, mask)
		@fact masked_hello --> b"Hello"

		DandelionWebSockets.masking!(hel, mask)
		@fact hel --> b"\x7f\x9f\x4d"
	end
end
