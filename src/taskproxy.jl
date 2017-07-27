# A `TaskProxy` is a proxy object for another object. A set of predefined functions are called on
# the task proxy, and those functions and their arguments are sent via a channel to another
# coroutine, that performs the function calls on the target object.

abstract type TaskProxy end

const ProxyCall = Tuple{Function, Vector{Any}}

macro taskproxy(proxy_type::Symbol, abstract_type::Symbol, target_type::Symbol, functions...)

    proxy_functions = []
    # For each function in the macro arguments, make a function that collects the arguments and
    # sends the symbol and args on a channel.
    for fname in functions
        fexpr = :($fname(p::$proxy_type, args...) = put!(p.chan, ($fname, collect(args))))
        push!(proxy_functions, fexpr)
    end

    esc(
        quote
            # Define the proxy type, which contains the target object this acts as a proxy for, and
            # the channel that functions and arguments are sent over.
            # The target object can be unset at the beginning, and set with a call to `attach`
            # later on.
            mutable struct $proxy_type <: $abstract_type
                target::Nullable{$target_type}
                chan::Channel{ProxyCall}

                $(proxy_type)() = new(Nullable{$target_type}(), Channel{ProxyCall}(32))
                $(proxy_type)(target::$target_type) =
                    new(Nullable{$target_type}(target), Channel{ProxyCall}(32))
            end

            $(proxy_functions...)

            function do_proxy(p::$proxy_type, target::$target_type)
                for (f, args) in p.chan
                    f(target, args...)
                end
            end

            function start(p::$proxy_type)
                if isnull(p.target)
                    error("Target not set in proxy $(p). Call `attach` or set in constructor")
                end
                target = get(p.target)
                @async do_proxy(p, target)
            end

            function stop(h::$proxy_type)
                close(h.chan)
                h.target = Nullable{$target_type}()
            end

            is_set(p::$proxy_type) = !isnull(p.target)

            "Set the target object for an empty task proxy."
            function attach(p::$proxy_type, target::$target_type)
                !isnull(p.target) && error("Target already set")
                p.chan = Channel{ProxyCall}(32)
                p.target = Nullable{$target_type}(target)
            end
        end
    )
end
