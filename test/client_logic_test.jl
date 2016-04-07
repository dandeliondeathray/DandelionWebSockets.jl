
typealias MockCall Tuple{Symbol,Array{Any, 1}}

type MockExecutor <: ClientLogicExecutor
	expected_calls::Array{MockCall}
end

type NoExpectedCallsException <: Exception end

function mockcall(m::MockExecutor, s::Symbol, args...)
	if length(m.expected_calls) == 0
		throw(NoExpectedCallsException())
	end
	expected_symbol, expected_args = shift!(m.expected_calls)
	
	@fact s --> expected_symbol
	@fact [args...] --> expected_args
end	

WebSocketClient.send_frame(m::MockExecutor, f::Frame) = mockcall(m, :send_frame, f)
WebSocketClient.text_received(m::MockExecutor, s::UTF8String) = mockcall(m, :text_received, s)

expect(m::MockExecutor, s::Symbol, args...) = push!(m.expected_calls, tuple(s, [args...]))
check_mock(m::MockExecutor) = @fact m.expected_calls --> isempty

test_frame1 = Frame(true, false, false, false, OPCODE_TEXT, false, 5, 0, nomask, b"Hello")

facts("ClientLogic") do
	context("Server message is received when state is open") do
		# Create a mock executor, and expect a single call to 
		# text_received(::ClientExecutor, ::Frame)
		# with the frame we send in to handle(::ClientLogic, ::FrameFromServer).
		m = MockExecutor([])
		expect(m, :text_received, utf8("Hello"))

		# Create a client in a open state, and tell it we got a frame from the server.
		c = ClientLogic(WebSocketClient.STATE_OPEN, m)
		WebSocketClient.handle(c, WebSocketClient.FrameFromServer(test_frame1))

		# Check that all expected calls were made.
		check_mock(m)
	end
end