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