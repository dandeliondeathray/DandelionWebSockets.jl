import DandelionWebSockets: @taskproxy, TaskProxy, start, stop, ProxyCall, attach, is_set

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
baz(m::MockTaskProxyTarget, s::String) = called(m, :baz, s)
qux(m::MockTaskProxyTarget, i::Int, s::String) = called(m, :qux, i, s)

function expect_call(m::MockTaskProxyTarget, f::Symbol, expected_args...)
    @fact isempty(m.call) --> false
    @fact isempty(m.args) --> false

    call = shift!(m.call)
    args = shift!(m.args)

    expected = [expected_args...]
    @fact call --> f
    @fact args --> expected
end

abstract type AbstractMockTaskProxy end
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
                baz(pump, "Hitchhiker")
                qux(pump, 42, "Hitchhiker")
                sleep(0.3)

                stop(pump)
                expect_call(t, :foo)
                expect_call(t, :bar, 42)
                expect_call(t, :baz, "Hitchhiker")
                expect_call(t, :qux, 42, "Hitchhiker")
            end
        end
    end

    context("Attach a target after TaskProxy creation") do
        t = MockTaskProxyTarget()
        proxy = MockTaskProxy()

        @fact is_set(proxy) --> false

        # We can't start a proxy before target is set.
        @fact_throws start(proxy) ErrorException

        attach(proxy, t)
        @fact is_set(proxy) --> true

        # Start does not throw an exception when a target has been attached.
        start(proxy)
    end

    context("Attaching twice leads to an exception") do
        t = MockTaskProxyTarget()
        proxy = MockTaskProxy()

        attach(proxy, t)
        @fact is_set(proxy) --> true

        @fact_throws attach(proxy, t) ErrorException

    end

    context("Attaching twice after a stop") do
        t = MockTaskProxyTarget()
        proxy = MockTaskProxy()

        attach(proxy, t)
        @fact is_set(proxy) --> true

        stop(proxy)

        attach(proxy, t)
        foo(proxy)
    end
end
