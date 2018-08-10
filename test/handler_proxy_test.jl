using Test
using DandelionWebSockets
using DandelionWebSockets.Proxy: WebSocketsHandlerProxy, stopproxy
import DandelionWebSockets: on_text, on_binary
import DandelionWebSockets: state_connecting, state_open, state_closing, state_closed

struct WebSocketsHandlerNotification
    method_name::String
    payload::Any
end

"""
This is a mock WebSocketHandler which is designed to verify that calls are made to the on_*
and state_* methods in a task separate from the client logic (which is the test in this
scenario). To verify this, the WebSocketHandler uses an unbuffered channel to inform the test
of callbacks. Therefore, if the test runs the `on_text()` method in the same task, then it will
block, because it cannot simultaneously take that notification from the channel.
"""
struct MockWebSocketsHandler <: WebSocketHandler
    notification::Channel{WebSocketsHandlerNotification}

    MockWebSocketsHandler() = new(Channel{WebSocketsHandlerNotification}(0))
end

takenotification!(h::MockWebSocketsHandler) = take!(h.notification)

on_text(h::MockWebSocketsHandler, text::String) = put!(h.notification, WebSocketsHandlerNotification("on_text", text))
on_binary(h::MockWebSocketsHandler, data::AbstractVector{UInt8}) = put!(h.notification, WebSocketsHandlerNotification("on_binary", data))
state_connecting(h::MockWebSocketsHandler) = put!(h.notification, WebSocketsHandlerNotification("state_connecting", ""))
state_open(h::MockWebSocketsHandler) = put!(h.notification, WebSocketsHandlerNotification("state_open", ""))
state_closing(h::MockWebSocketsHandler) = put!(h.notification, WebSocketsHandlerNotification("state_closing", ""))
state_closed(h::MockWebSocketsHandler) = put!(h.notification, WebSocketsHandlerNotification("state_closed", ""))

@testset "User handler proxy     " begin
    @testset "Callbacks are done in a separate task" begin
        @testset "on_text callback" begin
            # Arrange
            handler = MockWebSocketsHandler()
            handlerproxy = WebSocketsHandlerProxy(handler)

            # Act
            on_text(handlerproxy, "Some text")

            # Assert
            notification = takenotification!(handler)
            @test notification.method_name == "on_text"
            @test notification.payload == "Some text"
        end

        @testset "on_binary callback" begin
            # Arrange
            handler = MockWebSocketsHandler()
            handlerproxy = WebSocketsHandlerProxy(handler)

            # Act
            on_binary(handlerproxy, b"Some binary")

            # Assert
            notification = takenotification!(handler)
            @test notification.method_name == "on_binary"
            @test notification.payload == b"Some binary"
        end

        @testset "state_connecting callback" begin
            # Arrange
            handler = MockWebSocketsHandler()
            handlerproxy = WebSocketsHandlerProxy(handler)

            # Act
            state_connecting(handlerproxy)

            # Assert
            notification = takenotification!(handler)
            @test notification.method_name == "state_connecting"
        end

        @testset "state_open callback" begin
            # Arrange
            handler = MockWebSocketsHandler()
            handlerproxy = WebSocketsHandlerProxy(handler)

            # Act
            state_open(handlerproxy)

            # Assert
            notification = takenotification!(handler)
            @test notification.method_name == "state_open"
        end

        @testset "state_closing callback" begin
            # Arrange
            handler = MockWebSocketsHandler()
            handlerproxy = WebSocketsHandlerProxy(handler)

            # Act
            state_closing(handlerproxy)

            # Assert
            notification = takenotification!(handler)
            @test notification.method_name == "state_closing"
        end

        @testset "state_closed callback" begin
            # Arrange
            handler = MockWebSocketsHandler()
            handlerproxy = WebSocketsHandlerProxy(handler)

            # Act
            state_closed(handlerproxy)

            # Assert
            notification = takenotification!(handler)
            @test notification.method_name == "state_closed"
        end

        @testset "stop the proxy" begin
            # Arrange
            handler = MockWebSocketsHandler()
            handlerproxy = WebSocketsHandlerProxy(handler)

            # Act
            stopproxy(handlerproxy)

            # Assert
            @test isopen(handlerproxy.callbacks) == false
        end
    end
end