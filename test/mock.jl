import FactCheck: @fact

type MockCall
    sym::Symbol
    args::Vector{Any}
    return_value::Any
end

macro mock(mock_type::Symbol, abstract_type::Symbol)
    esc(
        quote
            type $mock_type <: $abstract_type
                calls::Vector{MockCall}

                $mock_type() = new([])
            end

            function check(m::$mock_type)
                @fact m.calls --> isempty
                empty!(m.calls)
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
            @fact ($t).calls --> not(isempty)
            mock_call = shift!(($t).calls)
            args = vcat($(params...))

            @fact $(Expr(:quote, function_sym)) --> mock_call.sym
            @fact args --> mock_call.args

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

macro expect(mock_object::Symbol, fcall::Expr, rvs...)
    sym = fcall.args[1]
    args = Vector{Any}(fcall.args[2:end])
    qargs = Vector{Any}()

    rv = nothing
    if !isempty(rvs)
        rv = rvs[1]
    end

    quote
        qargs = vcat($(args...))
        push!(($mock_object).calls, MockCall($(Expr(:quote, sym)), qargs, $rv))
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
end
