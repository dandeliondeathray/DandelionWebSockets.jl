import WebSocketClient: on_text, on_binary,
                        state_connecting, state_open, state_closing, state_closed,
                        @taskproxy, TaskProxy, start, stop,
                        HandlerTaskProxy

#
# Test types for our general pump.
#

type MockTaskProxyTarget
    call::Vector{Symbol}
    args::Vector{Vector{Any}}

    MockTaskProxyTarget() = new([], [])
end

function called(m::MockTaskProxyTarget, f::Symbol, args...)
    push!(m.call, f)
    push!(m.args, [args...])
end

foo(m::MockTaskProxyTarget) = called(m, :foo)
bar(m::MockTaskProxyTarget, i::Int) = called(m, :bar, i)
baz(m::MockTaskProxyTarget, s::UTF8String) = called(m, :baz, s)
qux(m::MockTaskProxyTarget, i::Int, s::UTF8String) = called(m, :qux, i, s)

function expect_call(m::MockTaskProxyTarget, f::Symbol, expected_args...)
    @fact m.call --> not(isempty)
    @fact m.args --> not(isempty)

    call = shift!(m.call)
    args = shift!(m.args)

    expected = [expected_args...]
    @fact call --> f
    @fact args --> expected
end

@taskproxy MockTaskProxy foo bar baz qux


immutable MockHandler <: WebSocketClient.WebSocketHandler
    texts::Vector{UTF8String}
    datas::Vector{Vector{UInt8}}
    states::Vector{Symbol}

    MockHandler() = new([], [], [])
end

on_text(h::MockHandler, text::UTF8String) = push!(h.texts, text)
on_binary(h::MockHandler, data::Vector{UInt8}) = push!(h.datas, data)

state_connecting(h::MockHandler) = push!(h.states, :state_connecting)
state_open(h::MockHandler) = push!(h.states, :state_open)
state_closing(h::MockHandler) = push!(h.states, :state_closing)
state_closed(h::MockHandler) = push!(h.states, :state_closed)

function expect_text(h::MockHandler, expected::UTF8String)
    @fact h.texts --> x -> !isempty(x)

    actual = shift!(h.texts)
    @fact actual --> expected
end

function expect_data(h::MockHandler, expected::Vector{UInt8})
    @fact h.datas --> not(isempty)

    actual = shift!(h.datas)
    @fact actual --> expected
end

function expect_state(h::MockHandler, expected::Symbol)
    @fact h.states --> x -> !isempty(x)

    actual = shift!(h.states)
    @fact actual --> expected
end

facts("Task proxy") do
    context("Start and stop") do
        t = MockTaskProxyTarget()
        pump = MockTaskProxy(t)
        task = start(pump)

        sleep(0.05)
        @fact task --> not(istaskdone)

        stop(pump)
        sleep(0.05)
        @fact task --> istaskdone
    end

    context("Calling functions on task proxy") do
        t = MockTaskProxyTarget()
        pump = MockTaskProxy(t)
        start(pump)

        foo(pump)
        bar(pump, 42)
        baz(pump, utf8("Hitchhiker"))
        qux(pump, 42, utf8("Hitchhiker"))
        sleep(0.1)

        stop(pump)
        expect_call(t, :foo)
        expect_call(t, :bar, 42)
        expect_call(t, :baz, utf8("Hitchhiker"))
        expect_call(t, :qux, 42, utf8("Hitchhiker"))
    end

    context("HandlerTaskProxy") do
        handler = MockHandler()
        proxy = HandlerTaskProxy(handler)

        @sync begin
            task = start(proxy)
            sleep(0.05)
            @fact task --> x -> !istaskdone(x)

            @async begin
                state_connecting(proxy)
                state_open(proxy)
                on_text(proxy, utf8("Hello"))
                on_binary(proxy, b"Hello")
                state_closing(proxy)
                state_closed(proxy)

                sleep(0.1)

                stop(proxy)
                sleep(0.05)
                @fact task --> istaskdone

                expect_state(handler, :state_connecting)
                expect_state(handler, :state_open)
                expect_text(handler, utf8("Hello"))
                expect_data(handler, b"Hello")
                expect_state(handler, :state_closing)
                expect_state(handler, :state_closed)
            end
        end
    end
end