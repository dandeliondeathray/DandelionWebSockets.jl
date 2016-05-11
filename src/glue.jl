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
# This task proxy takes messages from the executor and calls functions on the handler.
#

abstract TaskProxy

macro taskproxy(proxy_type::Symbol, functions...)

    proxy_functions = []
    for fname in functions
        fexpr = :($fname(p::$proxy_type, args...) = put!(p.chan, ($fname, [args...])))
        push!(proxy_functions, fexpr)
    end

    esc(
        quote
            immutable $proxy_type <: TaskProxy
                target::Any
                chan::Channel{Any}

                $(proxy_type)(target::Any) = new(target, Channel{Any}(32))
            end

            $(proxy_functions...)

            function start(p::$proxy_type)
                t = @async begin
                    for (f, args) in p.chan
                        f(p.target, args...)
                    end
                end
            end

            stop(h::$proxy_type) = close(h.chan)
        end
    )
end


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
