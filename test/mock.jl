import FactCheck: @fact

typealias MockCall Tuple{Symbol, Vector{Any}}
macro mock(mock_type::Symbol, abstract_type::Symbol)
    esc(
        quote
            type $mock_type <: $abstract_type
                calls::Vector{MockCall}
            end

            function check_mock(m::$mock_type)
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

abstract AbstractMockTester

module Baz
    bar(::Int, ::AbstractString) = nothing
end

import Baz: bar

@mock MockTester AbstractMockTester
@mockfunction MockTester foo bar

facts("Test mock") do
    t = MockTester([
        (:foo, []),
        (symbol("Baz.bar"), [42, "Hello"])
    ])

    foo(t)
    bar(t, 42, "Hello")

    check_mock(t)
end