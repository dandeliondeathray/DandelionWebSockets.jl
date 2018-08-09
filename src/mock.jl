# Create mock objects used in testing to check that the correct calls are made.
#
# This isn't used by the runtime for WebSockets. This is only used in testing. However, it is also
# used by the DandelionSlack project, for which this WebSocket package was built. All of this should
# ideally be in a separate package, and only used from tests. However, I'd prefer to keep the
# prerequisites for this package to a minimum, at least for now.

export @mock, @mockfunction, @expect, Throws, MockExpectationException,
       MockCall, ValueMatcher, mock_match, TypeMatcher, AbstractMatcher,
       mock_match

"Tells a mock function that it should throw an exception."
struct Throws
    ex::Exception
end

mock_action(action::Throws) = throw(action.ex)
mock_action(x::Any) = x

"An expected function call, along with expected arguments, and an action it should perform."
mutable struct MockCall
    sym::Symbol
    args::Vector{Any}
    action::Any
end

"An exception thrown when an unexpected argument was found or a function was called."
mutable struct MockExpectationException <: Exception
    s::AbstractString
end

MockExpectationException(expected::Any, actual::Any) =
    MockExpectationException("Expected $expected, but got $actual")
show(m::MockExpectationException) = "MockExpectationException: $(m.s)"

"""
Abstract type for objects that match actual arguments against expected arguments. For instance, we
sometimes don't care what value is provided a mock function, only what type it is. Also, this can
be used to parse an actual argument as JSON and compare the resulting object, rather than relying on
a string comparison.

All `AbstractMatcher` types `T` must define a function `mock_match(::T, v::Any)`.
"""
abstract type AbstractMatcher end

"Simply match a value by equality. This is the default."
struct ValueMatcher <: AbstractMatcher
    value::Any
end

mock_match(m::ValueMatcher, v::Any) = m.value == v || throw(MockExpectationException(m.value, v))
show(m::ValueMatcher) = show(m.value)

"Match a value by checking its type only."
struct TypeMatcher <: AbstractMatcher
    typ::DataType
end

mock_match(m::TypeMatcher, v::Any) =
    isa(v, m.typ) || throw(MockExpectationException(m.typ, typeof(v)))
show(m::TypeMatcher) = "TypeMatcher($(m.typ))"

"Define a mock type, given a symbol for its name and a type from which it should inherit."
macro mock(mock_type::Symbol, abstract_type::Symbol)
    esc(
        quote
            # Define the mock type. It should contain a list of the calls it expects.
            struct $mock_type <: $abstract_type
                calls::Vector{MockCall}

                $mock_type() = new([])
            end

            # Define a function that checks that all functions were in fact called.
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

"Define a name for an argument, if no name is provided."
function name_args_(fdef::Expr)
    function_sym = fdef.args[1]
    for a in fdef.args[2:end]
        if length(a.args) == 1
            unshift!(a.args, gensym(function_sym))
        end
    end
end

"""
Define one or more functions that mock the behaviour the object should have.

The functions defined here are the functions called by the code under test. The functions check that
their arguments match those that are expected, and that the mock action is performed.
"""
macro mockfunction(t::Symbol, fdefs...)
    funs = Vector{Expr}()
    for fdef in fdefs
        # Name all arguments in the function definition.
        name_args_(fdef)
        function_sym = fdef.args[1]
        params = [x.args[1] for x in fdef.args[2:end]]

        # A block of code that each function should have.
        # Basically, we collect all arguments. We get the next expected call, and then we match each
        # arguments against the expected value.
        check_call_block = quote
            args = vcat($(params...))
            called_sym = $(Expr(:quote, function_sym))

            if isempty(($t).calls)
                throw(MockExpectationException("Unexpected call $called_sym, with args $args"))
            end

            mock_call = shift!(($t).calls)

            # Check that the expected function is called.
            if called_sym != mock_call.sym
                throw(MockExpectationException(
                    "Expected call $(mock_call.sym)($(mock_call.args)) but got $(called_sym)($args)"))
            end

            # Check that we have the right number of args.
            if length(mock_call.args) != length(args)
                throw(MockExpectationException(
                    "Expected $(length(mock_call.args)) arguments, but got $(length(args)):" *
                    "Expected $(mock_call.args), but got $(args)"))
            end

            # Match each actual argument against the expected.
            for i in range(1, length(mock_call.args))
                matcher = mock_call.args[i]
                arg = args[i]
                DandelionWebSockets.mock_match(matcher, arg)
            end

            # Perform the action set with the @expect macro.
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

# For consistency, each expected value is wrapped with a matcher, even when that matcher merely
# checks for equality.
to_matcher(x::AbstractMatcher) = x
to_matcher(x::Any) = ValueMatcher(x)

"Expect a call with some arguments, and perform an action when that call has been made.."
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
