abstract type Notification end

struct OnText <: Notification
    payload::String
end

"""
WebSocketsHandlerProxy is a proxy object that calls the users WebSocketsHandler callbacks on a
dedicated task.
The purpose is to run the WebSockets client logic on a different task than the users code. This way,
the logic can keep handling control messages even when the users code is long running.
"""
struct WebSocketsHandlerProxy <: WebSocketHandler
    callbacks::Channel{Notification}
    handler::WebSocketHandler

    function WebSocketsHandlerProxy(handler::WebSocketHandler)
        proxy = new(Channel{Notification}(Inf), handler)
        @schedule handler_task(proxy)
        proxy
    end
end

function handler_task(w::WebSocketsHandlerProxy)
    for notification in w.callbacks
        handle(w, notification)
    end
end

handle(w::WebSocketsHandlerProxy, ontext::OnText) = on_text(w.handler, ontext.payload)

notify!(w::WebSocketsHandlerProxy, notification::Notification) = put!(w.callbacks, notification)

on_text(w::WebSocketsHandlerProxy, payload::String) = notify!(w, OnText(payload))
