using Base.Test
using DandelionWebSockets: AbstractFrameWriter, CloseStatus
using DandelionWebSockets: FailTheConnectionBehaviour, closetheconnection
using DandelionWebSockets: CLOSE_STATUS_PROTOCOL_ERROR
using DandelionWebSockets: FrameFromServer, clientprotocolinput, ClientProtocolInput
import DandelionWebSockets: closesocket

mutable struct FakeFrameWriter <: AbstractFrameWriter
    issocketclosed::Bool
    closestatuses::Vector{CloseStatus}
    closereasons::Vector{String}

    FakeFrameWriter() = new(false, [], [])
end

closesocket(w::FakeFrameWriter) = w.issocketclosed = true

send(w::FakeFrameWriter, isfinal::Bool, opcode::Opcode, payload::Vector{UInt8}) = nothing

function sendcloseframe(w::FakeFrameWriter, status::CloseStatus; reason::String="")
    push!(w.closestatuses, status)
    push!(w.closereasons, reason)
end

# A fake ClientProtocolInput, used to prove that the ClosingBehaviour can handle any input.
struct FakeClientProtocolInput <: ClientProtocolInput end

@testset "Fail the Connection    " begin
    @testset "Closes the socket" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        fail = FailTheConnectionBehaviour(framewriter, handler, CLOSE_STATUS_PROTOCOL_ERROR)

        closetheconnection(fail)

        @test framewriter.issocketclosed == true
    end

    @testset "Sends a frame if the socket is probably up" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        fail = FailTheConnectionBehaviour(framewriter, handler, CLOSE_STATUS_PROTOCOL_ERROR)

        closetheconnection(fail)

        @test framewriter.closestatuses[1] == CLOSE_STATUS_PROTOCOL_ERROR
    end

    @testset "Does not send a frame if the socket is probably down" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        fail = FailTheConnectionBehaviour(framewriter, handler, CLOSE_STATUS_PROTOCOL_ERROR;
                                          issocketprobablyup=false)

        closetheconnection(fail)

        @test framewriter.closestatuses == []
    end

    @testset "A reason is provided; The reason is present in the Close frame" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        fail = FailTheConnectionBehaviour(framewriter, handler, CLOSE_STATUS_PROTOCOL_ERROR;
                                          reason="Some reason")

        closetheconnection(fail)

        @test framewriter.closereasons[1] == "Some reason"
    end

    @testset "The state transitions to CLOSED" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        fail = FailTheConnectionBehaviour(framewriter, handler, CLOSE_STATUS_PROTOCOL_ERROR)

        closetheconnection(fail)

        @test handler.state == STATE_CLOSED
    end

    @testset "Close frame is received; No Close frame is sent in response" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        fail = FailTheConnectionBehaviour(framewriter, handler, CLOSE_STATUS_PROTOCOL_ERROR)

        closeframe = Frame(true, OPCODE_CLOSE, false, 0, 0, b"", b"")
        clientprotocolinput(fail, FrameFromServer(closeframe))

        @test length(framewriter.closestatuses) == 0
    end

    @testset "Can handle any type of ClientProtocolInput" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        fail = FailTheConnectionBehaviour(framewriter, handler, CLOSE_STATUS_PROTOCOL_ERROR)

        clientprotocolinput(fail, FakeClientProtocolInput())
    end
end