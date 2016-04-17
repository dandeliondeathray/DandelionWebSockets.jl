typealias MockCall Tuple{Symbol,Array{Any, 1}}

type MockExecutor <: WebSocketClient.AbstractClientExecutor
    expected_calls::Array{MockCall}
end

type UnexpectedCallException <: Exception end

function mockcall(m::MockExecutor, s::Symbol, args...)
    if length(m.expected_calls) == 0
        throw(UnexpectedCallException())
    end
    expected_symbol, expected_args = shift!(m.expected_calls)

    @fact s --> expected_symbol
    @fact Any[args...] --> expected_args
end

WebSocketClient.send_frame(m::MockExecutor, f::Frame) = mockcall(m, :send_frame, f)
WebSocketClient.text_received(m::MockExecutor, s::UTF8String) = mockcall(m, :text_received, s)
WebSocketClient.data_received(m::MockExecutor, s::Vector{UInt8}) = mockcall(m, :data_received, s)

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