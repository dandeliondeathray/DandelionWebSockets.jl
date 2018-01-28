
"""
WebSocketsHandlerProxy is a proxy object that calls the users WebSocketsHandler callbacks on a
dedicated task.
The purpose is to run the WebSockets client logic on a different task than the users code. This way,
the logic can keep handling control messages even when the users code is long running.
"""
struct WebSocketsHandlerProxy <: WebSocketHandler
    callbacks::Channel{Any}
    handler::WebSocketHandler

    function WebSocketsHandlerProxy(handler::WebSocketHandler)
        proxy = new(Channel{Any}(Inf), handler)
        @schedule handler_task(proxy)
        proxy
    end
end

function handler_task(w::WebSocketsHandlerProxy)
    for notification in w.callbacks
        handle(w, notification)
    end
end

handle(w::WebSocketsHandlerProxy, text::String) = on_text(w.handler, text)
handle(w::WebSocketsHandlerProxy, payload::Vector{UInt8}) = on_binary(w.handler, payload)
function handle(w::WebSocketsHandlerProxy, state::SocketState)
    state_connecting(w.handler)
end

notify!(w::WebSocketsHandlerProxy, notification::Any) = put!(w.callbacks, notification)

on_text(w::WebSocketsHandlerProxy, payload::String) = notify!(w, payload)
on_binary(w::WebSocketsHandlerProxy, payload::Vector{UInt8}) = notify!(w, payload)
state_connecting(w::WebSocketsHandlerProxy) = notify!(w, STATE_CONNECTING)