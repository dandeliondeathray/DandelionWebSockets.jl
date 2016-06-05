export @mock, @mockfunction, @expect, Throws, MockExpectationException,
       MockCall, ValueMatcher, mock_match, TypeMatcher, AbstractMatcher,
       mock_match

immutable Throws
    ex::Exception
end

mock_action(action::Throws) = throw(action.ex)
mock_action(x::Any) = x

type MockCall
    sym::Symbol
    args::Vector{Any}
    action::Any
end

type MockExpectationException <: Exception
    s::AbstractString
end

MockExpectationException(expected::Any, actual::Any) =
    MockExpectationException("Expected $expected, but got $actual")
show(m::MockExpectationException) = "MockExpectationException: $(m.s)"


abstract AbstractMatcher

immutable ValueMatcher <: AbstractMatcher
    value::Any
end

mock_match(m::ValueMatcher, v::Any) = m.value == v || throw(MockExpectationException(m.value, v))
show(m::ValueMatcher) = show(m.value)

immutable TypeMatcher <: AbstractMatcher
    typ::DataType
end

mock_match(m::TypeMatcher, v::Any) =
    isa(v, m.typ) || throw(MockExpectationException(m.typ, typeof(v)))
show(m::TypeMatcher) = "TypeMatcher($(m.typ))"

macro mock(mock_type::Symbol, abstract_type::Symbol)
    esc(
        quote
            type $mock_type <: $abstract_type
                calls::Vector{MockCall}

                $mock_type() = new([])
            end

            function check(m::$mock_type)
                try
                    if !isempty(m.calls)
                        throw(MockExpectationException("Missing calls: $(m.calls)"))
                    end
                finally
                    empty!(m.calls)
                end
            end
        end
    )
end

function name_args_(fdef::Expr)
    function_sym = fdef.args[1]
    for a in fdef.args[2:end]
        if length(a.args) == 1
            unshift!(a.args, gensym(function_sym))
        end
    end
end

macro mockfunction(t::Symbol, fdefs...)
    funs = Vector{Expr}()
    for fdef in fdefs
        name_args_(fdef)
        function_sym = fdef.args[1]
        params = [x.args[1] for x in fdef.args[2:end]]

        check_call_block = quote
            args = vcat($(params...))
            called_sym = $(Expr(:quote, function_sym))

            if isempty(($t).calls)
                throw(MockExpectationException("Unexpected call $called_sym, with args $args"))
            end

            mock_call = shift!(($t).calls)

            if called_sym != mock_call.sym
                throw(MockExpectationException(
                    "Expected call $(mock_call.sym)($(mock_call.args)) but got $(called_sym)($args)"))
            end

            if length(mock_call.args) != length(args)
                throw(MockExpectationException(
                    "Expected $(length(mock_call.args)) arguments, but got $(length(args)):" *
                    "Expected $(mock_call.args), but got $(args)"))
            end

            for i in range(1, length(mock_call.args))
                matcher = mock_call.args[i]
                arg = args[i]
                DandelionWebSockets.mock_match(matcher, arg)
            end

            return DandelionWebSockets.mock_action(mock_call.action)
        end

        fun = Expr(:function)
        push!(fun.args, fdef)
        push!(fun.args, check_call_block)

        push!(funs, fun)
    end

    esc(quote
        $(funs...)
    end)
end

to_matcher(x::AbstractMatcher) = x
to_matcher(x::Any) = ValueMatcher(x)

macro expect(mock_object::Symbol, fcall::Expr, rvs...)
    sym = fcall.args[1]
    args = Vector{Any}(fcall.args[2:end])

    rv = nothing
    if !isempty(rvs)
        rv = rvs[1]
    end

    quote
        qargs = vcat($([esc(x) for x in args]...))
        match_args = [to_matcher(x) for x in qargs]
        push!(($(esc(mock_object))).calls, MockCall($(Expr(:quote, sym)), match_args, $(esc(rv))))
    end
end
