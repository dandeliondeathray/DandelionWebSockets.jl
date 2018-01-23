using Base.Test
using DandelionWebSockets: STATE_CLOSING_SOCKET

function closeframe_from_server(; payload::Vector{UInt8} = b"")
    Frame(true, OPCODE_CLOSE, false, length(payload), 0, Vector{UInt8}(), payload)
end

@testset "Connection management" begin
    @testset "the server initiates a closing handshake" begin
        @testset "state is CLOSING_SOCKET" begin
            logic, handler, writer = makeclientlogic(state=STATE_OPEN)
        
            close_frame = closeframe_from_server()
            handle(logic, FrameFromServer(close_frame))

            @test logic.state == STATE_CLOSING_SOCKET
        end

        @testset "handler is notified of state change" begin
            logic, handler, writer = makeclientlogic(state=STATE_OPEN)
        
            close_frame = closeframe_from_server()
            handle(logic, FrameFromServer(close_frame))

            @test handler.state == STATE_CLOSING
        end

        @testset "a close frame is sent in reply" begin
            logic, handler, writer = makeclientlogic(state=STATE_OPEN)
        
            close_frame = closeframe_from_server()
            handle(logic, FrameFromServer(close_frame))

            frame = getframe(writer, 1)
            @test frame.opcode == OPCODE_CLOSE
        end
    end
end