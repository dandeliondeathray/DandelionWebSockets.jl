using Test
using DandelionWebSockets: CloseRequest, SocketClosed, protocolstate
using DandelionWebSockets: PongMissed, STATE_CLOSING

@testset "Connection management  " begin
    @testset "the server initiates a closing handshake" begin
        @testset "state is CLOSING" begin
            logic, handler, writer = makeclientlogic()

            close_frame = closeframe_from_server()
            handle(logic, FrameFromServer(close_frame))

            @test protocolstate(logic) == STATE_CLOSING
        end

        @testset "handler is notified of state change" begin
            logic, handler, writer = makeclientlogic()

            close_frame = closeframe_from_server()
            handle(logic, FrameFromServer(close_frame))

            @test handler.state == STATE_CLOSING
        end

        @testset "a close frame is sent in reply" begin
            logic, handler, writer = makeclientlogic()

            close_frame = closeframe_from_server()
            handle(logic, FrameFromServer(close_frame))

            frame = getframe(writer, 1)
            @test frame.opcode == OPCODE_CLOSE
        end
    end

    @testset "the client initiates a closing handshake" begin
        @testset "state is CLOSING" begin
            # Requirement
            # @7_1_2-1 Start the closing handshake

            logic, handler, writer = makeclientlogic()

            handle(logic, CloseRequest())

            @test protocolstate(logic) == STATE_CLOSING
        end

        @testset "handler is notified of state change" begin
            logic, handler, writer = makeclientlogic()

            handle(logic, CloseRequest())

            @test handler.state == STATE_CLOSING
        end

        @testset "a close frame is sent" begin
            logic, handler, writer = makeclientlogic()

            handle(logic, CloseRequest())

            frame = getframe(writer, 1)
            @test frame.opcode == OPCODE_CLOSE
        end
    end

    @testset "the server replies to a client initiated closing handshake" begin
        @testset "state is CLOSING" begin
            logic, handler, writer = makeclientlogic()

            handle(logic, CloseRequest())
            close_frame = closeframe_from_server()
            handle(logic, FrameFromServer(close_frame))

            @test protocolstate(logic) == STATE_CLOSING
        end
    end

    @testset "the socket is closed cleanly" begin
        @testset "the state is CLOSED" begin
            logic, handler, writer = makeclientlogic()

            handle(logic, CloseRequest())
            close_frame = closeframe_from_server()
            handle(logic, FrameFromServer(close_frame))
            handle(logic, SocketClosed())

            @test protocolstate(logic) == STATE_CLOSED
        end

        @testset "the handler is notified of the state change" begin
            logic, handler, writer = makeclientlogic()

            handle(logic, CloseRequest())
            close_frame = closeframe_from_server()
            handle(logic, FrameFromServer(close_frame))
            handle(logic, SocketClosed())

            @test handler.state == STATE_CLOSED
        end

        @testset "the client cleanup function is called" begin
            was_client_cleanup_called = false
            client_cleanup = () -> was_client_cleanup_called = true
            # TODO Rewrite to put in correct closing state
            logic, handler, writer = makeclientlogic(client_cleanup=client_cleanup)

            handle(logic, CloseRequest())
            close_frame = closeframe_from_server()
            handle(logic, FrameFromServer(close_frame))
            handle(logic, SocketClosed())

            @test was_client_cleanup_called == true
        end
    end

    @testset "close connection if enough pongs have been missed" begin
        @testset "state is closed" begin
            logic, handler, writer = makeclientlogic()

            handle(logic, PongMissed())

            @test protocolstate(logic) == STATE_CLOSED
        end

        @testset "handler is notified of the state change" begin
            logic, handler, writer = makeclientlogic()

            handle(logic, PongMissed())

            @test handler.state == STATE_CLOSED
        end
    end

    @testset "User request to close the connection during a close; Another Close frame is not sent" begin
        # Arrange
        logic, handler, writer = makeclientlogic()
        close_frame = closeframe_from_server()
        handle(logic, FrameFromServer(close_frame))
        # A Close frame is sent here.

        # Act
        handle(logic, CloseRequest())
        # A Close frame is _not_ sent here.

        # Assert
        # Only one close frame should have been sent.
        @test get_no_of_frames_written(writer) == 1
    end

    @testset "Socket unexpectedly closed; Connection is failed" begin
        logic, handler, writer = makeclientlogic()

        handle(logic, SocketClosed())

        @test protocolstate(logic) == STATE_CLOSED
    end

    @testset "Socket closed after client close request; handler is not notified twice" begin
        logic, handler, writer = makeclientlogic()

        handle(logic, CloseRequest())
        close_frame = closeframe_from_server()
        handle(logic, FrameFromServer(close_frame))
        handle(logic, SocketClosed())

        @test handler.statesequence == [STATE_CLOSING, STATE_CLOSED]
    end
end
