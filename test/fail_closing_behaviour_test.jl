using Base.Test
using DandelionWebSockets: AbstractFrameWriter, CloseStatus
using DandelionWebSockets: FailTheConnectionBehaviour, closetheconnection
using DandelionWebSockets: CLOSE_STATUS_PROTOCOL_ERROR
import DandelionWebSockets: closesocket

mutable struct FakeFrameWriter <: AbstractFrameWriter
    issocketclosed::Bool
    closestatuses::Vector{CloseStatus}

    FakeFrameWriter() = new(false, [])
end

closesocket(w::FakeFrameWriter) = w.issocketclosed = true

send(w::FakeFrameWriter, isfinal::Bool, opcode::Opcode, payload::Vector{UInt8}) = nothing

function sendcloseframe(w::FakeFrameWriter, status::CloseStatus; reason::String="")
    push!(w.closestatuses, status)
end

@testset "Fail the Connection    " begin
    @testset "Closes the socket" begin
        framewriter = FakeFrameWriter()
        fail = FailTheConnectionBehaviour(framewriter, CLOSE_STATUS_PROTOCOL_ERROR)

        closetheconnection(fail)

        @test framewriter.issocketclosed == true
    end

    @testset "Sends a frame if the socket is probably up" begin
        framewriter = FakeFrameWriter()
        fail = FailTheConnectionBehaviour(framewriter, CLOSE_STATUS_PROTOCOL_ERROR)

        closetheconnection(fail)

        @test framewriter.closestatuses[1] == CLOSE_STATUS_PROTOCOL_ERROR
    end

    @testset "Does not send a frame if the socket is probably down" begin
        framewriter = FakeFrameWriter()
        fail = FailTheConnectionBehaviour(framewriter, CLOSE_STATUS_PROTOCOL_ERROR; issocketprobablyup=false)

        closetheconnection(fail)

        @test framewriter.closestatuses == []
    end
end