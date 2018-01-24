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

logic_tests = []


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
