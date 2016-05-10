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

# TODO: This glue is overly specific. We should be able to make a general pump that pumps a
#       function call on a given object, and apply it. That way, the executor will say:
#       "Call the function `on_text` on your handler object, with these arguments.", instead of
#       creating a separate type for each such call. Then we can get rid of the types OnText,
#       OnBinary, StateOpen, and so on, because they're used to convey that same information.

immutable HandlerPump
    chan::Channel{HandlerType}
    task::Task
end

handle(handler::WebSocketHandler, t::OnText) = on_text(handler, t.text)
handle(handler::WebSocketHandler, t::OnBinary) = on_binary(handler, t.data)
handle(handler::WebSocketHandler, ::StateOpen) = state_open(handler)
handle(handler::WebSocketHandler, ::StateConnecting) = state_connecting(handler)
handle(handler::WebSocketHandler, ::StateClosing) = state_closing(handler)
handle(handler::WebSocketHandler, ::StateClosed) = state_closed(handler)

function start(::Type{HandlerPump}, handler::WebSocketHandler, chan::Channel{HandlerType})
    t = @async begin
        for x in chan
            handle(handler, x)
        end
    end
    HandlerPump(chan, t)
end

stop(h::HandlerPump) = close(h.chan)
