typealias MockCall Tuple{Symbol,Array{Any, 1}}

type MockExecutor <: WebSocketClient.AbstractClientExecutor
    expected_calls::Array{MockCall}
end

type UnexpectedCallException <: Exception end

function mockcall(m::MockExecutor, s::Symbol, args...)
    @fact m.expected_calls --> x -> !isempty(x)
    expected_symbol, expected_args = shift!(m.expected_calls)

    @fact s --> expected_symbol
    @fact Any[args...] --> expected_args
end

WebSocketClient.send_frame(m::MockExecutor, f::Frame) = mockcall(m, :send_frame, f)
WebSocketClient.on_text(m::MockExecutor, s::UTF8String) = mockcall(m, :on_text, s)
WebSocketClient.data_received(m::MockExecutor, s::Vector{UInt8}) = mockcall(m, :data_received, s)
WebSocketClient.state_closed(m::MockExecutor) = mockcall(m, :state_closed)
WebSocketClient.state_closing(m::MockExecutor) = mockcall(m, :state_closing)

expect(m::MockExecutor, s::Symbol, args...) = push!(m.expected_calls, tuple(s, [args...]))
check_mock(m::MockExecutor) = @fact m.expected_calls --> isempty

type FakeRNG <: AbstractRNG
    values::Array{UInt8, 1}

    FakeRNG(v::Array{UInt8, 1}) = new(copy(v))
end

FakeRNG() = FakeRNG(Array{UInt8, 1}())

function Base.rand(rng::FakeRNG, ::Type{UInt8}, n::Int)
    @fact rng.values --> x -> !isempty(x)
    splice!(rng.values, 1:n)
end

#
# A lot of tests use WebSocket frames, naturally, so these are common frames that all tests can use.
#

nomask = Array{UInt8,1}()
mask = b"\x37\xfa\x21\x3d"

# A single frame with payload "Hello"
test_frame1 = Frame(true,  OPCODE_TEXT,         false, 5, 0, nomask, b"Hello")

# Two fragments of a text message with payload "Hello"
test_frame2 = Frame(false, OPCODE_TEXT,         false, 3, 0, nomask, b"Hel")
test_frame3 = Frame(true,  OPCODE_CONTINUATION, false, 2, 0, nomask, b"lo")

# A single text frame, masked, with body "Hello"
test_frame4 = Frame(true,  OPCODE_TEXT, true, 5, 0, mask, b"\x7f\x9f\x4d\x51\x58")

mask2 = b"\x17\x42\x03\x7f"

# Two masked fragments, one initial and one final. They are masked by two different masks.
test_frame5 = Frame(false, OPCODE_TEXT, true, 3, 0, mask, b"\x7f\x9f\x4d")
test_frame6 = Frame(true, OPCODE_CONTINUATION, true, 2, 0,  mask2, b"\x7b\x2d")

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
