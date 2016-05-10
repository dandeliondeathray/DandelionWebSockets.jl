type FakeInput1 <: WebSocketClient.ClientLogicInput end
type FakeInput2 <: WebSocketClient.ClientLogicInput end

type MockClientLogic
    inputs::Vector{WebSocketClient.ClientLogicInput}
end

mock_handle(c::MockClientLogic, x::WebSocketClient.ClientLogicInput) = push!(c.inputs, x)

function expect(c::MockClientLogic, expected::WebSocketClient.ClientLogicInput)
    @fact c.inputs --> x -> !isempty(x)

    actual = shift!(c.inputs)
    @fact actual --> expected
end

facts("ClientLogicPump") do
    context("Start and stop") do
        client = MockClientLogic([])
        chan   = Channel{WebSocketClient.ClientLogicInput}(32)
        handle = x -> mock_handle(client, x)

        pump   = WebSocketClient.start_client_logic_pump(handle, chan)
        sleep(0.05)
        @fact pump.task --> x -> !istaskdone(x)

        WebSocketClient.stop_client_logic_pump(pump)
        sleep(0.05)
        @fact pump.task --> istaskdone
    end

    context("Pumping objects into channel") do
        client = MockClientLogic([])
        chan   = Channel{WebSocketClient.ClientLogicInput}(32)
        handle = x -> mock_handle(client, x)

        @sync begin
            pump   = WebSocketClient.start_client_logic_pump(handle, chan)
            sleep(0.05)
            @fact pump.task --> x -> !istaskdone(x)

            @async begin
                put!(chan, FakeInput1())
                put!(chan, FakeInput2())
                put!(chan, FakeInput2())

                sleep(0.1)
                expect(client, FakeInput1())
                expect(client, FakeInput2())
                expect(client, FakeInput2())

                WebSocketClient.stop_client_logic_pump(pump)
                sleep(0.05)
                @fact pump.task --> istaskdone
            end
        end
    end

end

immutable MockHandler <: WebSocketClient.WebSocketHandler
    texts::Vector{UTF8String}
    states::Vector{Symbol}
end

WebSocketClient.on_text(h::MockHandler, text::UTF8String) = push!(h.texts, text)
WebSocketClient.on_close(h::MockHandler) = push!(h.states, :onclose)

function expect_text(h::MockHandler, expected::UTF8String)
    @fact h.texts --> x -> !isempty(x)

    actual = shift!(h.texts)
    @fact actual --> expected
end

function expect_state(h::MockHandler, expected::Symbol)
    @fact h.states --> x -> !isempty(x)

    actual = shift!(h.states)
    @fact actual --> expected
end

facts("WebClientHandler pump") do
    context("Start and stop") do
        handler = MockHandler([], [])
        chan    = Channel{WebSocketClient.HandlerType}(32)
        pump   = WebSocketClient.start(WebSocketClient.HandlerPump, handler, chan)
        sleep(0.05)
        @fact pump.task --> x -> !istaskdone(x)

        WebSocketClient.stop(pump)
        sleep(0.05)
        @fact pump.task --> istaskdone
    end

    context("Pumping objects into channel") do
        handler = MockHandler([], [])
        chan    = Channel{WebSocketClient.HandlerType}(32)

        @sync begin
            pump   = WebSocketClient.start(WebSocketClient.HandlerPump, handler, chan)
            sleep(0.05)
            @fact pump.task --> x -> !istaskdone(x)

            @async begin
                put!(chan, WebSocketClient.OnText(utf8("Hello")))
                put!(chan, WebSocketClient.StateClose())

                sleep(0.1)

                WebSocketClient.stop(pump)
                sleep(0.05)
                @fact pump.task --> istaskdone

                expect_text(handler, utf8("Hello"))
                expect_state(handler, :onclose)
            end
        end
    end

end