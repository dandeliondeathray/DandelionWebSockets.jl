abstract type AbstractMockTester end

module Baz
    bar(::Int, ::AbstractString) = nothing
    struct BazType end
end

import Baz: bar, BazType

struct MyException <: Exception
    msg::AbstractString
end

@mock MockTester AbstractMockTester
t = MockTester()
@mockfunction(t,
    foo(::MockTester, ::Int, ::Int),
    bar(a::String, ::Int),
    baz(x::Vector{UInt8}))

facts("Test mock") do
    context("Expectations") do
        some_arg = 17

        @expect t foo(t, some_arg, 42)
        @expect t bar("Hello", -5) 42
        @expect t baz(b"Hello")

        @fact foo(t, some_arg, 42) --> nothing
        @fact bar("Hello", -5) --> 42
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
        mock_match(ValueMatcher(42), 42)
        @fact_throws mock_match(ValueMatcher(42), 43)
        @fact_throws mock_match(ValueMatcher(42), "42")

        mock_match(TypeMatcher(Int), 42)
        @fact_throws mock_match(TypeMatcher(Int), "")
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

    context("MockThrowAction") do
        @expect t foo(t, 17, 42) Throws(MyException("some error"))

        @fact_throws foo(t, 17, 42) MyException

        check(t)
    end
end
