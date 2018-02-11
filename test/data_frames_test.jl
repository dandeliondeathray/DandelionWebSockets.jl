# These tests cover section 5.6 in the RFC6455 WebSocket specification.

@testset "Data frames            " begin
    @testset "A text message fragment may include only a partial UTF-8 sequence" begin
        # Tests that the client supports getting two text frames that are separately invalid UTF-8,
        # but together form valid UTF-8.
        #
        # Requirement
        # @5_6-1 Partial UTF-8 sequences

        logic, handler, writer = makeclientlogic()

        text = "\u2200"
        # Split the above text into two parts that are both invalid UTF-8:
        payload = Vector{UInt8}(text)
        payload1 = payload[1:1]
        payload2 = payload[2:end]

        frame1 = Frame(false, OPCODE_TEXT, false, length(payload1), 0, Vector{UInt8}(), payload1)
        frame2 = Frame(true, OPCODE_CONTINUATION, false, length(payload2), 0, Vector{UInt8}(), payload2)

        handle(logic, FrameFromServer(frame1))
        handle(logic, FrameFromServer(frame2))

        @test gettextat(handler, 1) == text
    end
end