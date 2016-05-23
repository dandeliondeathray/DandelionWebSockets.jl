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
            end
        end
    )
end

macro mockfunction(mock_type::Symbol, functions...)
    mocks = []
    for f in functions
        local fsym = symbol("$f")
        m = quote
            function $f(m::$mock_type, args...)
                @fact m.calls --> not(isempty)

                call = shift!(m.calls)

                @fact symbol($f) --> call[1]
                @fact collect(args) --> collect(call[2])
            end
        end
        push!(mocks, m)
    end

    esc(
        quote
            $(mocks...)
        end)
end

macro expect(fcall::Expr, rv::Any)
    dump(fcall)
    println()
    dump(rv)
    println()
end

abstract AbstractMockTester

module Baz
    bar(::Int, ::AbstractString) = nothing
end

import Baz: bar

@mock MockTester AbstractMockTester
@mockfunction MockTester foo bar

facts("Test mock") do
    context("Expectations") do
        t = MockTester()

        @expect foo(t, 17) nothing
        @expect bar(t, utf8("Hello")) 42

        @fact foo(t, 17) --> nothing
        @fact bar(t, utf8("Hello")) --> 42

        check(t)
    end
end

