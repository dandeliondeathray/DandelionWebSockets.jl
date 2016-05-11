import WebSocketClient: @taskproxy, TaskProxy, start, stop

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
    @fact isempty(m.call) --> false
    @fact isempty(m.args) --> false

    call = shift!(m.call)
    args = shift!(m.args)

    expected = [expected_args...]
    @fact call --> f
    @fact args --> expected
end

abstract AbstractMockTaskProxy
@taskproxy MockTaskProxy AbstractMockTaskProxy MockTaskProxyTarget foo bar baz qux

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
        @sync begin
            @schedule begin
                start(pump)

                foo(pump)
                bar(pump, 42)
                baz(pump, utf8("Hitchhiker"))
                qux(pump, 42, utf8("Hitchhiker"))
                sleep(0.3)

                stop(pump)
                expect_call(t, :foo)
                expect_call(t, :bar, 42)
                expect_call(t, :baz, utf8("Hitchhiker"))
                expect_call(t, :qux, 42, utf8("Hitchhiker"))
            end
        end
    end
end