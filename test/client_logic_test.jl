immutable LogicTestCase
	description::AbstractString
	initial_state::WebSocketClient.SocketState
	rng::FakeRNG
	#frames::Dict{AbstractString, Frame}
	input::Vector{Any} # This will contain types such as FrameFromServer or SendTextFrame
	expected_calls::Vector{MockCall}
end

function LogicTestCase(;
	description="",
	initial_state=WebSocketClient.STATE_CONNECTING,
	rng=FakeRNG(),
	input=[],
	expected_calls=[])

	LogicTestCase(description, initial_state, rng, input, expected_calls)
end

test_frame1 = Frame(true, false, false, false, OPCODE_TEXT, false, 5, 0, nomask, b"Hello")
test_frame2 = Frame(false, false, false, false, OPCODE_TEXT, false, 3, 0, nomask, b"Hel")
test_frame3 = Frame(true, false, false, false, OPCODE_CONTINUATION, false, 2, 0, nomask, b"lo")

# A single text frame, masked, with body "Hello"
test_frame4 = Frame(true, false, false, false, OPCODE_TEXT, true, 5, 0,
	mask, b"\x7f\x9f\x4d\x51\x58")

mask2 = b"\x17\x42\x03\x7f"

# Two masked fragments, one initial and one final. They are masked by two different masks.
test_frame5 = Frame(false, false, false, false, OPCODE_TEXT, true, 3, 0,
	mask, b"\x7f\x9f\x4d")
test_frame6 = Frame(true, false, false, false, OPCODE_CONTINUATION, true, 2, 0,
	mask2, b"\x7b\x2d")

logic_tests = [

	#
	# Server to client tests
	#

	LogicTestCase(
		description    = "A message from the server is received",
		initial_state  = WebSocketClient.STATE_OPEN,
		rng            = FakeRNG(b""),
		input          = [WebSocketClient.FrameFromServer(test_frame1)],
		expected_calls = [(:text_received, [utf8("Hello")])]),

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