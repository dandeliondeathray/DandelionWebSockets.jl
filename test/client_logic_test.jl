
typealias MockCall Tuple{Symbol,Array{Any, 1}}

type MockExecutor <: ClientLogicExecutor
	expected_calls::Array{MockCall}
end

type UnexpectedCallException <: Exception end

function mockcall(m::MockExecutor, s::Symbol, args...)
	if length(m.expected_calls) == 0
		throw(UnexpectedCallException())
	end
	expected_symbol, expected_args = shift!(m.expected_calls)

	@fact s --> expected_symbol
	@fact [args...] --> expected_args
end

WebSocketClient.send_frame(m::MockExecutor, f::Frame) = mockcall(m, :send_frame, f)
WebSocketClient.text_received(m::MockExecutor, s::UTF8String) = mockcall(m, :text_received, s)

expect(m::MockExecutor, s::Symbol, args...) = push!(m.expected_calls, tuple(s, [args...]))
check_mock(m::MockExecutor) = @fact m.expected_calls --> isempty

type FakeRNG <: AbstractRNG
	values::Array{UInt8, 1}

	FakeRNG(v::Array{UInt8, 1}) = new(copy(v))
end

FakeRNG() = FakeRNG(Array{UInt8, 1}())

function Base.rand(rng::FakeRNG, ::Type{UInt8}, n::Int)
	if length(rng.values) < n
		throw(UnexpectedCallException())
	end
	splice!(rng.values, 1:n)
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

facts("ClientLogic") do
	#
	# Server to client tests
	#
	context("Server message is received") do
		# Create a mock executor, and expect a single call to
		# text_received(::ClientExecutor, ::Frame)
		# with the frame we send in to handle(::ClientLogic, ::FrameFromServer).
		m = MockExecutor([])
		expect(m, :text_received, utf8("Hello"))

		# The RNG is not expected to be used in this case, since no frames will be sent.
		rng = FakeRNG()

		# Create a client in a open state, and tell it we got a frame from the server.
		c = ClientLogic(WebSocketClient.STATE_OPEN, m, rng)
		WebSocketClient.handle(c, WebSocketClient.FrameFromServer(test_frame1))

		# Check that all expected calls were made.
		check_mock(m)
	end

	#
	# Client to server tests
	#

	context("Client sends a message") do
		m = MockExecutor([])
		expect(m, :send_frame, test_frame4)

		# Seed the fake RNG with the mask value we want for this test
		rng = FakeRNG(mask)

		c = ClientLogic(WebSocketClient.STATE_OPEN, m, rng)
		WebSocketClient.handle(c, WebSocketClient.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT))

		check_mock(m)
	end

	context("Client sends two fragments") do
		m = MockExecutor([])
		expect(m, :send_frame, test_frame5)
		expect(m, :send_frame, test_frame6)

		# Seed the fake RNG with the mask value we want for this test
		rng = FakeRNG(vcat(mask, mask2))

		c = ClientLogic(WebSocketClient.STATE_OPEN, m, rng)
		WebSocketClient.handle(c,
			WebSocketClient.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT))
		WebSocketClient.handle(c,
			WebSocketClient.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION))

		check_mock(m)
	end

	context("Frames are not sent when in CLOSING") do
		m = MockExecutor([])
		rng = FakeRNG()

		c = ClientLogic(WebSocketClient.STATE_CLOSING, m, rng)
		WebSocketClient.handle(c, WebSocketClient.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT))
		WebSocketClient.handle(c,
			WebSocketClient.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT))
		WebSocketClient.handle(c,
			WebSocketClient.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION))

		check_mock(m)
	end

	context("Frames are not sent when in CONNECTING") do
		m = MockExecutor([])
		rng = FakeRNG()

		c = ClientLogic(WebSocketClient.STATE_CONNECTING, m, rng)
		WebSocketClient.handle(c, WebSocketClient.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT))
		WebSocketClient.handle(c,
			WebSocketClient.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT))
		WebSocketClient.handle(c,
			WebSocketClient.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION))

		check_mock(m)
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