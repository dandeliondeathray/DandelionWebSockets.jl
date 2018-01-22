using Base.Test

@testset "Client to server" begin
    @testset "send single-frame text message; message is sent" begin
        # Arrange
        mask = b"\x01\x02\x03\x04"
        logic, handler, writer = makeclientlogic(mask=mask)

        # Act
        handle(logic, SendTextFrame("Hello", true, OPCODE_TEXT))

        # Assert
        frame = getframeunmasked(writer, 1, mask)
        @test frame.payload == b"Hello"
        @test frame.fin == true
        @test frame.opcode == OPCODE_TEXT
    end
end