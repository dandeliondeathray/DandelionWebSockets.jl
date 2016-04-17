export WebSocketHandler,
       text_received,
       on_close

abstract WebSocketHandler

text_received(t::WebSocketHandler, ::UTF8String) = error("text_received not implemented for $(t)")
on_close(t::WebSocketHandler) = error("on_close not implemented for $(t)")
on_create(t::WebSocketHandler) = error("on_create not implemented for $(t)")
on_closing(t::WebSocketHandler) = error("on_closing not implemented for $(t)")