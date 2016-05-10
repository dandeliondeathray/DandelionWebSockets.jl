export WebSocketHandler,
       on_text,
       on_binary,
       on_create,
       state_closed,
       state_closing,
       state_connecting,
       state_open


abstract WebSocketHandler

on_text(t::WebSocketHandler, ::UTF8String) = error("on_text not implemented for $(typeof(t))")
on_binary(t::WebSocketHandler, ::Vector{UInt8}) = error("on_binary not implemented for $(typeof(t))")
on_create(t::WebSocketHandler) = error("on_create not implemented for $(typeof(t))")
state_closed(t::WebSocketHandler) = error("state_closed not implemented for $(typeof(t))")
state_closing(t::WebSocketHandler) = error("state_closing not implemented for $(typeof(t))")
state_connecting(t::WebSocketHandler) = error("state_connecting not implemented for $(typeof(t))")
state_open(t::WebSocketHandler) = error("state_open not implemented for $(typeof(t))")
