export WebSocketHandler,
       text_received,
       on_close

abstract WebSocketHandler

text_received(t::WebSocketHandler, ::UTF8String) = error("text_received not implemented for $(t)")
on_close(t::WebSocketHandler) = error("on_close not implemented for $(t)")

