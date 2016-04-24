export WebSocketHandler,
       on_text,
       on_close

abstract WebSocketHandler

on_text(t::WebSocketHandler, ::UTF8String) = error("on_text not implemented for $(t)")
on_close(t::WebSocketHandler) = error("on_close not implemented for $(t)")
on_create(t::WebSocketHandler) = error("on_create not implemented for $(t)")
on_closing(t::WebSocketHandler) = error("on_closing not implemented for $(t)")