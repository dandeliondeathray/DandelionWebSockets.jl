import DandelionWebSockets: on_text, on_binary,
    state_connecting, state_open, state_closing, state_closed,
    write, handle, FrameFromServer

import Base.==

#
# A lot of tests use WebSocket frames, naturally, so these are common frames that all tests can use.
#

nomask = Array{UInt8,1}()
testmask = b"\x37\xfa\x21\x3d"

# A single frame with payload "Hello"
test_frame1 = Frame(true,  OPCODE_TEXT,         false, 5, 0, nomask, b"Hello")

# Two fragments of a text message with payload "Hello"
test_frame2 = Frame(false, OPCODE_TEXT,         false, 3, 0, nomask, b"Hel")
test_frame3 = Frame(true,  OPCODE_CONTINUATION, false, 2, 0, nomask, b"lo")

# A single text frame, masked, with body "Hello"
test_frame4 = Frame(true,  OPCODE_TEXT, true, 5, 0, testmask, b"\x7f\x9f\x4d\x51\x58")
test_bin_frame4 = Frame(true,  OPCODE_BINARY, true, 5, 0, testmask, b"\x7f\x9f\x4d\x51\x58")

mask2 = b"\x17\x42\x03\x7f"

# Two masked fragments, one initial and one final. They are masked by two different masks.
test_frame5 = Frame(false, OPCODE_TEXT, true, 3, 0, testmask, b"\x7f\x9f\x4d")
test_frame6 = Frame(true, OPCODE_CONTINUATION, true, 2, 0,  mask2, b"\x7b\x2d")

# Two binary fragments, one initial and one final.
frame_bin_start = Frame(false, OPCODE_BINARY,       false, 3, 0, nomask, b"Hel")
frame_bin_final = Frame(true,  OPCODE_CONTINUATION, false, 2, 0, nomask, b"lo")
frame_bin_1     = Frame(true,  OPCODE_BINARY,       false, 5, 0, nomask, b"Hello")

server_close_frame = Frame(true, OPCODE_CLOSE, false, 0, 0, nomask, b"")
client_close_reply = Frame(true, OPCODE_CLOSE, true, 0, 0, testmask, b"")
server_ping_frame = Frame(true, OPCODE_PING, false, 0, 0, nomask, b"")
client_pong_frame = Frame(true, OPCODE_PONG, true, 0, 0, testmask, b"")
server_pong_frame = Frame(true, OPCODE_PONG, false, 0, 0, nomask, b"")
client_ping_frame = Frame(true, OPCODE_PING, true, 0, 0, testmask, b"")
server_ping_frame_w_pay = Frame(true, OPCODE_PING, false, 5, 0, nomask, b"Hello")
client_pong_frame_w_pay = Frame(true, OPCODE_PONG, true, 5, 0, testmask, b"\x7f\x9f\x4d\x51\x58")

zero256 = Array{UInt8}([UInt8(0) for x in range(1, length=256)])
zero65k = Array{UInt8}([UInt8(0) for x in range(1, length=65536 + 1024)])
zero256_masked = Array{UInt8}([zero256[i] ⊻ testmask[(i-1)%4 + 1] for i in 1:length(zero256)])
zero65k_masked = Array{UInt8}([zero65k[i] ⊻ testmask[(i-1)%4 + 1] for i in 1:length(zero65k)])

# Binary message, payload is 256 bytes, single masked
test_bin_frame_256 = Frame(true, OPCODE_BINARY, true, 126, 256, testmask, zero256_masked)

# Binary message, payload is 64KiB, masked
test_bin_frame_65k = Frame(true, OPCODE_BINARY, true, 127, 65536 + 1024, testmask, zero65k_masked)


#
# To accurately test a fake TCPSocket I need a blocking stream.
# The implementation below is meant to be simple, not performant or good.
#
struct BlockingStream <: IO
    buf::IOBuffer
end

function blocking_read(s::BlockingStream)
    x = nothing
    while true
        try
            x = read(s.buf, UInt8)
            return x
        catch ex
            if !isa(ex, EOFError)
                rethrow(ex)
            end
        end
        sleep(0.05)
    end
    x
end

function Base.read(s::BlockingStream, ::Type{UInt8})
    blocking_read(s)
end

function Base.read(s::BlockingStream, ::Type{Array{UInt8, 1}}, n::Int)
    buf = Array{UInt8, 1}(n)
    for i in 1:n
        buf[i] = blocking_read(s)
    end
    buf
end

function Base.read(s::BlockingStream, ::Type{UInt64})
    buf = read(s, Array{UInt8, 1}, 8)
    x::UInt64 =
        buf[1] << 56 | buf[2] << 48 << buf[3] << 40 | buf[4] << 32 |
        buf[5] << 24 | buf[6] << 16 << buf[7] << 8  | buf[8]
    x
end

function Base.read(s::BlockingStream, ::Type{UInt16})
    buf = read(s, Array{UInt8, 1}, 2)
    x::UInt16 = buf[1] << 8 | buf[2]
    x
end

#
# MockClientProtocol mocks ClientProtocol, and should have used the @mock macro, except that there are
# issues with FactCheck and doing asserts in other tasks. This custom mock ensures that all asserts
# are done afterwards, in the same task that created it.
#

==(a::FrameFromServer, b::FrameFromServer) = a.frame == b.frame

const MockLogicCall = Tuple{Symbol, Vector{Any}}

mutable struct MockClientProtocol <: AbstractClientProtocol
    actuals::Vector{MockLogicCall}
    expected::Vector{MockLogicCall}

    MockClientProtocol(expected::Vector{MockLogicCall}) = new([], expected)
end

function call(m::MockClientProtocol, s::Symbol, args...)
    push!(m.actuals, (s, collect(args)))
end

function check(m::MockClientProtocol)
    #@fact m.actuals --> m.expected
end

handle(m::MockClientProtocol, args...) = call(m, :handle, args...)

#
# A fake stream for checking that we read and write the right frames.
#

struct FakeFrameStream <: IO
    reading::Vector{Frame}
    writing::Vector{Frame}
    close_on_empty::Bool
    stop_chan::Channel{Symbol}

    FakeFrameStream(reading::Vector{Frame}, writing::Vector{Frame}, close_on_empty::Bool) =
        new(reading, writing, close_on_empty, Channel{Symbol}(32))
end

function Base.read(s::FakeFrameStream, ::Type{Frame})
    if isempty(s.reading)
        if s.close_on_empty
            throw(EOFError())
        else
            take!(s.stop_chan)
            throw(EOFError())
        end
    end
    sleep(0.2)
    shift!(s.reading)
end

function Base.write(s::FakeFrameStream, frame::Frame)
    push!(s.writing, frame)
    if frame.opcode == DandelionWebSockets.OPCODE_CLOSE
        put!(s.stop_chan, :stop)
    end
end

Base.close(s::FakeFrameStream) = nothing