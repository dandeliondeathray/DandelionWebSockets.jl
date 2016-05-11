import WebSocketClient: AbstractHandlerTaskProxy, AbstractWriterTaskProxy,
    on_text, on_binary,
    state_connecting, state_open, state_closing, state_closed,
    write

@mock MockHandlerTaskProxy AbstractHandlerTaskProxy
@mockfunction(MockHandlerTaskProxy,
    on_text, on_binary,
    state_connecting, state_open, state_closing, state_closed)

@mock MockWriterTaskProxy AbstractWriterTaskProxy
@mockfunction MockWriterTaskProxy write

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
