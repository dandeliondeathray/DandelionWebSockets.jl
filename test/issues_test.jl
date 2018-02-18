using Base.Test

@testset "Issues                 " begin
    @testset "Issue #12: Masking frames should be done on a copy of data" begin
        # Arrange
        logic, handler, writer = makeclientlogic()

        text = "Foo"

        # Act
        handle(logic, SendTextFrame(text, true, OPCODE_TEXT))

        # Assert
        @test text == "Foo"
    end
end