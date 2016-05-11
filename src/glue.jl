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
                t
            end

            stop(h::$proxy_type) = close(h.chan)
        end
    )
end

@taskproxy HandlerTaskProxy on_text on_binary state_connecting state_open state_closing state_closed
@taskproxy ClientLogicTaskProxy handle