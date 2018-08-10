using DandelionWebSockets: FrameWriter, CLOSE_STATUS_NO_STATUS, CLOSE_STATUS_GOING_AWAY, closesocket
import DandelionWebSockets: sendcloseframe

@testset "Frame writer           " begin
    @testset "Write close frame with CLOSE_STATUS_NO_STATUS; No body in the frame" begin
        frameio = FrameIOStub()
        rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04")
        framewriter = FrameWriter(frameio, rng)

        sendcloseframe(framewriter, CLOSE_STATUS_NO_STATUS)

        frame = getframe(frameio, 1)
        @test isempty(frame.payload)
    end

    @testset "Write close frame with CLOSE_STATUS_GOING_AWAY; Body starts with that code" begin
        frameio = FrameIOStub()
        mask = b"\x01\x02\x03\x04"
        rng = FakeRNG{UInt8}(mask)
        framewriter = FrameWriter(frameio, rng)

        sendcloseframe(framewriter, CLOSE_STATUS_GOING_AWAY)

        frame = getframeunmasked(frameio, 1, mask)
        payload = IOBuffer(frame.payload)
        @test read(payload, UInt16) == hton(CLOSE_STATUS_GOING_AWAY.code)
    end

    @testset "Write close frame with reason; Body has text included" begin
        frameio = FrameIOStub()
        mask = b"\x01\x02\x03\x04"
        rng = FakeRNG{UInt8}(mask)
        framewriter = FrameWriter(frameio, rng)
        reason = "Some reason text"

        sendcloseframe(framewriter, CLOSE_STATUS_GOING_AWAY; reason=reason)

        frame = getframeunmasked(frameio, 1, mask)

        # Check first that length matches the status code plus reason
        @test length(frame.payload) == 2 + length(reason) # Status code and reason

        # Skip the 16 bit status code and read the reason
        payload = IOBuffer(frame.payload)
        skip(payload, 2)
        @test read(payload, length(reason)) == Vector{UInt8}(reason)
    end

    @testset "Write close frame with no status, but reason; No reason is included" begin
        frameio = FrameIOStub()
        rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04")
        framewriter = FrameWriter(frameio, rng)

        sendcloseframe(framewriter, CLOSE_STATUS_NO_STATUS; reason = "Some reason")

        frame = getframe(frameio, 1)
        @test isempty(frame.payload)
    end

    @testset "Closing the socket; Underlying stream is not open" begin
        frameio = FrameIOStub()
        rng = FakeRNG{UInt8}(b"")
        framewriter = FrameWriter(frameio, rng)

        closesocket(framewriter)

        @test frameio.isopen == false
    end
end