import FactCheck: @fact

type MockCall
    sym::Symbol
    args::Vector{Any}
    return_value::Any
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

match(m::ValueMatcher, v::Any) = m.value == v || throw(MockExpectationException(m.value, v))
show(m::ValueMatcher) = show(m.value)

immutable TypeMatcher <: AbstractMatcher
    typ::DataType
end

match(m::TypeMatcher, v::Any) =
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
                match(matcher, arg)
            end

            mock_call.return_value
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
        qargs = vcat($(args...))
        match_args = [to_matcher(x) for x in qargs]
        push!(($mock_object).calls, MockCall($(Expr(:quote, sym)), match_args, $rv))
    end
end

abstract AbstractMockTester

module Baz
    bar(::Int, ::AbstractString) = nothing
    immutable BazType end
end

import Baz: bar, BazType

@mock MockTester AbstractMockTester
t = MockTester()
@mockfunction(t,
    foo(::MockTester, ::Int, ::Int),
    bar(a::UTF8String, ::Int),
    baz(x::Vector{UInt8}))

facts("Test mock") do
    context("Expectations") do
        some_arg = 17

        @expect t foo(t, some_arg, 42)
        @expect t bar(utf8("Hello"), -5) 42
        @expect t baz(b"Hello")

        @fact foo(t, some_arg, 42) --> nothing
        @fact bar(utf8("Hello"), -5) --> 42
        @fact baz(b"Hello") --> nothing

        check(t)
    end

    context("Failed expectation") do
        @expect t foo(t, 17, 42)

        @fact_throws foo(t, 17, 43) MockExpectationException

        check(t)
    end

    context("Missing calls") do
        @expect t foo(t, 17, 42)

        @fact_throws check(t) MockExpectationException
        @fact t.calls --> isempty
    end

    context("Unexpected call") do
        @fact_throws foo(t, 17, 42)

        check(t)
    end

    context("Wrong number of arguments") do
        @expect t foo(t, 17, 42, 43)

        @fact_throws foo(t, 17, 42) MockExpectationException

        check(t)
    end

    context("Matchers") do
        match(ValueMatcher(42), 42)
        @fact_throws match(ValueMatcher(42), 43)
        @fact_throws match(ValueMatcher(42), "42")

        match(TypeMatcher(Int), 42)
        @fact_throws match(TypeMatcher(Int), "")
    end

    context("Using TypeMatcher") do
        @expect t foo(t, TypeMatcher(Int), 42)
        @expect t foo(t, TypeMatcher(Number), 42)
        @expect t foo(t, TypeMatcher(AbstractString), 42)

        foo(t, 17, 42)
        foo(t, 18, 42)
        @fact_throws foo(t, 19, 42) MockExpectationException
        check(t)
    end
end
