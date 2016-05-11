abstract TaskProxy

macro taskproxy(proxy_type::Symbol, abstract_type::Symbol, target_type::Symbol, functions...)

    proxy_functions = []
    for fname in functions
        fexpr = :($fname(p::$proxy_type, args...) = put!(p.chan, ($fname, [args...])))
        push!(proxy_functions, fexpr)
    end

    esc(
        quote
            immutable $proxy_type <: $abstract_type
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