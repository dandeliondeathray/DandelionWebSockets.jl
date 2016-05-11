#
# This file defines the proxies that proxies calls from the ClientLogic task to the tasks where the
# WebSocketHandler type runs, and the frame writer, and so on.
#

@taskproxy(HandlerTaskProxy, AbstractHandlerTaskProxy, WebSocketHandler,
    on_text, on_binary,
    state_connecting, state_open, state_closing, state_closed)

@taskproxy ClientLogicTaskProxy AbstractClientTaskProxy ClientLogic handle
@taskproxy WriterTaskProxy AbstractWriterTaskProxy IO write