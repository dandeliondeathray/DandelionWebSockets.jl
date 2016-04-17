# This function takes ClientLogicInput objects from a channel and calls the appropriate
# function on ClientLogic.
# This glue is there because we want ClientLogic to be a simple object with functions
# without any concurrency involved, for testing purposes.

type ClientLogicPump
    handle::Function
    chan::Channel{ClientLogicInput}
    task::Task
end

function start_client_logic_pump(handle::Function, chan::Channel{ClientLogicInput})
    t = @async begin
        for o in chan
            handle(o)
        end
    end
    ClientLogicPump(handle, chan, t)
end

function stop_client_logic_pump(t::ClientLogicPump)
    close(t.chan)
end

#
# This pump takes messages from the executor and calls functions on the handler.
#

immutable HandlerPump
    chan::Channel{HandlerType}
    task::Task
end

handle(handler::WebSocketHandler, t::TextReceived) = text_received(handler, t.text)
handle(handler::WebSocketHandler, ::OnClose) = on_close(handler)

function start(::Type{HandlerPump}, handler::WebSocketHandler, chan::Channel{HandlerType})
    t = @async begin
        for x in chan
            handle(handler, x)
        end
    end
    HandlerPump(chan, t)
end

stop(h::HandlerPump) = close(h.chan)
