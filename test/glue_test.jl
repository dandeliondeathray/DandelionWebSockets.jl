import DandelionWebSockets: on_text, on_binary,
                        state_connecting, state_open, state_closing, state_closed,
                        start, stop, HandlerTaskProxy


immutable MockHandler <: DandelionWebSockets.WebSocketHandler
    texts::Vector{String}
    datas::Vector{Vector{UInt8}}
    states::Vector{Symbol}

    MockHandler() = new([], [], [])
end

on_text(h::MockHandler, text::String) = push!(h.texts, text)
on_binary(h::MockHandler, data::Vector{UInt8}) = push!(h.datas, data)

state_connecting(h::MockHandler) = push!(h.states, :state_connecting)
state_open(h::MockHandler) = push!(h.states, :state_open)
state_closing(h::MockHandler) = push!(h.states, :state_closing)
state_closed(h::MockHandler) = push!(h.states, :state_closed)

function expect_text(h::MockHandler, expected::String)
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
    context("HandlerTaskProxy") do
        handler = MockHandler()
        proxy = HandlerTaskProxy(handler)

        task = start(proxy)
        sleep(0.05)
        @fact task --> x -> !istaskdone(x)

        state_connecting(proxy)
        state_open(proxy)
        on_text(proxy, "Hello")
        on_binary(proxy, b"Hello")
        state_closing(proxy)
        state_closed(proxy)

        sleep(0.1)

        stop(proxy)
        sleep(0.05)
        @fact task --> istaskdone

        expect_state(handler, :state_connecting)
        expect_state(handler, :state_open)
        expect_text(handler, "Hello")
        expect_data(handler, b"Hello")
        expect_state(handler, :state_closing)
        expect_state(handler, :state_closed)
    end
end
