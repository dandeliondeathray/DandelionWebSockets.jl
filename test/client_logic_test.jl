immutable LogicTestCase
	description::AbstractString
	initial_state::WebSocketClient.SocketState
	rng::FakeRNG
	#frames::Dict{AbstractString, Frame}
	input::Vector{Any} # This will contain types such as FrameFromServer or SendTextFrame
	expected_calls::Vector{MockCall}
	final_state::WebSocketClient.SocketState
end

function LogicTestCase(;
	description="",
	initial_state=WebSocketClient.STATE_CONNECTING,
	rng=FakeRNG(),
	input=[],
	expected_calls=[],
	final_state=initial_state)

	LogicTestCase(description, initial_state, rng, input, expected_calls, final_state)
end

# A single text frame, masked, with body "Hello"
test_frame4 = Frame(true,  OPCODE_TEXT, true, 5, 0, mask, b"\x7f\x9f\x4d\x51\x58")

mask2 = b"\x17\x42\x03\x7f"

# Two masked fragments, one initial and one final. They are masked by two different masks.
test_frame5 = Frame(false, OPCODE_TEXT, true, 3, 0,	mask, b"\x7f\x9f\x4d")
test_frame6 = Frame(true, OPCODE_CONTINUATION, true, 2, 0,	mask2, b"\x7b\x2d")

# Two binary fragments, one initial and one final.
frame_bin_start = Frame(false, OPCODE_BINARY,       false, 3, 0, nomask, b"Hel")
frame_bin_final = Frame(true,  OPCODE_CONTINUATION, false, 2, 0, nomask, b"lo")
frame_bin_1     = Frame(true,  OPCODE_BINARY,       false, 5, 0, nomask, b"Hello")

server_close_frame = Frame(true, OPCODE_CLOSE, false, 0, 0, nomask, b"")
client_close_reply = Frame(true, OPCODE_CLOSE, true, 0, 0, mask, b"")
server_ping_frame = Frame(true, OPCODE_PING, false, 0, 0, nomask, b"")
client_pong_frame = Frame(true, OPCODE_PONG, true, 0, 0, mask, b"")
server_ping_frame_w_pay = Frame(true, OPCODE_PING, false, 5, 0, nomask, b"Hello")
client_pong_frame_w_pay = Frame(true, OPCODE_PONG, true, 5, 0, mask, b"\x7f\x9f\x4d\x51\x58")

logic_tests = [

	#
	# Server to client tests
	#

	LogicTestCase(
		description    = "A text message from the server is received",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(b""),
		input          = [WebSocketClient.FrameFromServer(test_frame1)],
		expected_calls = [(:text_received, [utf8("Hello")])]),

	LogicTestCase(
		description    = "Two text fragments are received from the server",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(),
		input          = [WebSocketClient.FrameFromServer(test_frame2),
		                  WebSocketClient.FrameFromServer(test_frame3)],
		expected_calls = [(:text_received, [utf8("Hello")])]),

	LogicTestCase(
		description    = "Buffer is cleared between two separate multi-fragment messages",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(),
		input          = [WebSocketClient.FrameFromServer(test_frame2),
		                  WebSocketClient.FrameFromServer(test_frame3),
		                  WebSocketClient.FrameFromServer(test_frame2),
		                  WebSocketClient.FrameFromServer(test_frame3)],
		expected_calls = [(:text_received, [utf8("Hello")]),
		                  (:text_received, [utf8("Hello")])]),

	LogicTestCase(
		description    = "A ping request is received between two fragments",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [WebSocketClient.FrameFromServer(test_frame2),
						  WebSocketClient.FrameFromServer(server_ping_frame),
		                  WebSocketClient.FrameFromServer(test_frame3)],
		expected_calls = [(:send_frame, [client_pong_frame]),
		                  (:text_received, [utf8("Hello")])]),

	LogicTestCase(
		description    = "A pong response has the same payload as the ping",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [WebSocketClient.FrameFromServer(server_ping_frame_w_pay)],
		expected_calls = [(:send_frame, [client_pong_frame_w_pay])]),


	LogicTestCase(
		description    = "A binary message from the server is received",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(b""),
		input          = [WebSocketClient.FrameFromServer(frame_bin_1)],
		expected_calls = [(:data_received, Array[b"Hello"])]),

	LogicTestCase(
		description    = "Two binary fragments are received from the server",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(),
		input          = [WebSocketClient.FrameFromServer(frame_bin_start),
		                  WebSocketClient.FrameFromServer(frame_bin_final)],
		expected_calls = [(:data_received, Array[b"Hello"])]),

	#
	# Client to server tests
	#

	LogicTestCase(
		description    = "Client sends a message",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [WebSocketClient.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT)],
		expected_calls = [(:send_frame, [test_frame4])]),

	LogicTestCase(
		description    = "Client sends two fragments",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(vcat(mask, mask2)),
		input          = [WebSocketClient.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT),
		                  WebSocketClient.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION)],
		expected_calls = [(:send_frame, [test_frame5]),
		                  (:send_frame, [test_frame6])]),

	LogicTestCase(
		description    = "Frames are not sent when in CLOSING",
		initial_state  = WebSocketClient.STATE_CLOSING,
		rng            = FakeRNG(),
		input          = [WebSocketClient.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT),
						  WebSocketClient.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT),
		                  WebSocketClient.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION)],
		expected_calls = []),

	LogicTestCase(
		description    = "Frames are not sent when in CONNECTING",
		initial_state  = WebSocketClient.STATE_CONNECTING,
		rng            = FakeRNG(),
		input          = [WebSocketClient.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT),
						  WebSocketClient.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT),
		                  WebSocketClient.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION)],
		expected_calls = []),

	LogicTestCase(
		description    = "Frames are not sent when in CLOSED",
		initial_state  = WebSocketClient.STATE_CLOSED,
		rng            = FakeRNG(),
		input          = [WebSocketClient.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT),
						  WebSocketClient.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT),
		                  WebSocketClient.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION)],
		expected_calls = []),

	#
	# Closing the connection
	#

	LogicTestCase(
		description    = "The server initiates a closing handshake.",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [WebSocketClient.FrameFromServer(server_close_frame)],
		expected_calls = [(:send_frame,    [client_close_reply]),
		                  (:state_closing, [])],
		final_state    = WebSocketClient.STATE_CLOSING_SOCKET),

	LogicTestCase(
		description    = "The client initiates a closing handshake.",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [WebSocketClient.CloseRequest()],
		expected_calls = [(:send_frame,    [client_close_reply]),
		                  (:state_closing, [])],
		final_state    = WebSocketClient.STATE_CLOSING),

	LogicTestCase(
		description    = "The server replies to a client initiated handshake",
		initial_state  = WebSocketClient.STATE_CLOSING,
		rng            = FakeRNG(),
		input          = [WebSocketClient.FrameFromServer(server_close_frame)],
		expected_calls = [],
		final_state    = WebSocketClient.STATE_CLOSING_SOCKET),

	LogicTestCase(
		description    = "The socket is closed cleanly",
		initial_state  = WebSocketClient.STATE_CLOSING_SOCKET,
		rng            = FakeRNG(),
		input          = [WebSocketClient.SocketClosed()],
		expected_calls = [(:state_closed, [])],
		final_state    = WebSocketClient.STATE_CLOSED),

]

facts("ClientLogic") do
	#
	# Declarative tests
	#

	for test in logic_tests
		context(test.description) do
			executor = MockExecutor(test.expected_calls)
			logic = ClientLogic(test.initial_state, executor, test.rng)

			for x in test.input
				WebSocketClient.handle(logic, x)
			end

			@fact logic.state --> test.final_state

			check_mock(executor)
		end
	end


	#
	# Utilities
	#

	context("Masking") do
		hello = b"Hello"
		hel   = b"Hel"
		masked_hello = b"\x7f\x9f\x4d\x51\x58"

		WebSocketClient.masking!(hello, mask)
		@fact hello --> b"\x7f\x9f\x4d\x51\x58"

		WebSocketClient.masking!(masked_hello, mask)
		@fact masked_hello --> b"Hello"

		WebSocketClient.masking!(hel, mask)
		@fact hel --> b"\x7f\x9f\x4d"
	end
end