abstract TaskProxy

typealias ProxyCall Tuple{Function, Vector{Any}}

macro taskproxy(proxy_type::Symbol, abstract_type::Symbol, target_type::Symbol, functions...)

    proxy_functions = []
    for fname in functions
        fexpr = :($fname(p::$proxy_type, args...) = put!(p.chan, ($fname, collect(args))))
        push!(proxy_functions, fexpr)
    end

    esc(
        quote
            type $proxy_type <: $abstract_type
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

            stop(h::$proxy_type) = close(h.chan)

            is_set(p::$proxy_type) = !isnull(p.target)

            function attach(p::$proxy_type, target::$target_type)
                !isnull(p.target) && error("Target already set")

                p.target = Nullable{$target_type}(target)
            end
        end
    )
end