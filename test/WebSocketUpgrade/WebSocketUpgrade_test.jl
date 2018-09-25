using Test
using DandelionWebSockets.WebSocketUpgrade

todata(xs...) = codeunits(join(xs))

@testset "WebSocketUpgrade       " begin
    @testset "ResponseParser; A complete HTTP response without excess; The parser has a complete HTTP response" begin
        # Arrange
        response = todata(
            "HTTP/1.1 101 Switch Protocols\r\n",
            "Date: Sun, 06 Nov 1994 08:49:37 GMT\r\n",
            "\r\n",
        )

        parser = ResponseParser()

        # Act
        dataread(parser, response)

        # Assert
        @test hascompleteresponse(parser)
    end

end