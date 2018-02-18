using Base.Test
using DandelionWebSockets: AbstractFrameWriter, CloseStatus
using DandelionWebSockets: FailTheConnectionBehaviour, closetheconnection, ClientInitiatedCloseBehaviour
using DandelionWebSockets: CLOSE_STATUS_PROTOCOL_ERROR, CLOSE_STATUS_NORMAL
using DandelionWebSockets: FrameFromServer, clientprotocolinput, ClientProtocolInput, protocolstate
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

    @testset "The state is STATE_CLOSED" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        fail = FailTheConnectionBehaviour(framewriter, handler, CLOSE_STATUS_PROTOCOL_ERROR)

        closetheconnection(fail)

        @test protocolstate(fail) == STATE_CLOSED
    end
end

@testset "Closing the Connection " begin
    @testset "Close status code is by default CLOSE_STATUS_NORMAL" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        normal = ClientInitiatedCloseBehaviour(framewriter, handler)

        closetheconnection(normal)

        @test framewriter.closestatuses[1] == CLOSE_STATUS_NORMAL
    end

    @testset "An optional close status can be specified" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        normal = ClientInitiatedCloseBehaviour(framewriter, handler; status=CLOSE_STATUS_GOING_AWAY)

        closetheconnection(normal)

        @test framewriter.closestatuses[1] == CLOSE_STATUS_GOING_AWAY
    end

    @testset "An optional reason can be specified" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        normal = ClientInitiatedCloseBehaviour(framewriter, handler; reason="Some reason")

        closetheconnection(normal)

        @test framewriter.closereasons[1] == "Some reason"
    end

    @testset "After a Close frame has been sent, the user is notified that the state is CLOSING" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        normal = ClientInitiatedCloseBehaviour(framewriter, handler)

        closetheconnection(normal)

        @test handler.state == STATE_CLOSING
    end

    @testset "After a Close frame has been sent, the client state is CLOSING" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        normal = ClientInitiatedCloseBehaviour(framewriter, handler)

        closetheconnection(normal)

        @test protocolstate(normal) == STATE_CLOSING
    end

    @testset "A Close frame response is received, the client state is CLOSED" begin
        framewriter = FakeFrameWriter()
        handler = WebSocketHandlerStub()
        normal = ClientInitiatedCloseBehaviour(framewriter, handler)

        closetheconnection(normal)
        closeframe = Frame(true, OPCODE_CLOSE, false, 0, 0, b"", b"")
        clientprotocolinput(normal, FrameFromServer(closeframe))

        @test protocolstate(normal) == STATE_CLOSED
    end
end