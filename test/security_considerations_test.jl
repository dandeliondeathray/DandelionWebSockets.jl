# Security Considerations
# =======================
# These are tests that map directly against section 10 "Security Considerations" in the
# RFC 6455 WebSocket specification.

@testset "Security considerations" begin
    @testset "Client must choose a new masking key for each frame" begin
        # Requirement
        # @10_3-1

        # Arrange
        mask = b"\x01\x02\x03\x04\x05\x06\x07\x08"
        logic, handler, writer = makeclientlogic(mask=mask)

        # Act
        text = "Hello"
        handle(logic, SendTextFrame(text, true, OPCODE_TEXT))
        handle(logic, SendTextFrame(text, true, OPCODE_TEXT))

        # Assert
        frame1 = getframe(writer, 1)
        frame2 = getframe(writer, 2)
        @test frame1.payload != frame2.payload
    end
end