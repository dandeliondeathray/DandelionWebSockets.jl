using Base.Test
using DandelionWebSockets
using DandelionWebSockets: WebSocketsHandlerProxy
import DandelionWebSockets: on_text

"""
This is a mock WebSocketHandler which is designed to verify that calls are made to the on_*
and state_* methods in a task separate from the client logic (which is the test in this
scenario). To verify this, the WebSocketHandler uses an unbuffered channel to inform the test
of callbacks. Therefore, if the test runs the `on_text()` method in the same task, then it will
block, because it cannot simultaneously take that notification from the channel.
"""
struct Notification
    method_name::String
    payload::Any
end

struct MockWebSocketsHandler <: WebSocketHandler
    notification::Channel{Notification}

    MockWebSocketsHandler() = new(Channel{Notification}(0))
end

takenotification!(h::MockWebSocketsHandler) = take!(h.notification)

on_text(h::MockWebSocketsHandler, text::String) = put!(h.notification, Notification("on_text", text))

@testset "WebSocketHandler" begin
    @testset "Callbacks are done in a separate task" begin
        @testset "on_text callback" begin
            handler = MockWebSocketsHandler()
            handlerproxy = WebSocketsHandlerProxy(handler)

            on_text(handlerproxy, "Some text")

            notification = takenotification!(handler)
            @test notification.method_name == "on_text"
            @test notification.payload == "Some text"
        end
    end
end