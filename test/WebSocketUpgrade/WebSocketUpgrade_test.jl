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

    @testset "ResponseParser; No empty line; The parser does not have a complete response" begin
        # Arrange
        response = todata(
            "HTTP/1.1 101 Switch Protocols\r\n",
            "Date: Sun, 06 Nov 1994 08:49:37 GMT\r\n",
        )

        parser = ResponseParser()

        # Act
        dataread(parser, response)

        # Assert
        @test !hascompleteresponse(parser)
    end

    @testset "ResponseParser; A complete response with some excess data; The parser has a complete response" begin
        # Arrange
        response = todata(
            "HTTP/1.1 101 Switch Protocols\r\n",
            "Date: Sun, 06 Nov 1994 08:49:37 GMT\r\n",
            "\r\n",
            "Some excess data"
        )

        parser = ResponseParser()

        # Act
        dataread(parser, response)

        # Assert
        @test hascompleteresponse(parser)
    end

    @testset "ResponseParser; Complete response in two parts; The parser has a complete response" begin
        # Arrange
        response1 = todata(
            "HTTP/1.1 101 Switch Protocols\r\n",
        )
        response2 = todata(
            "Date: Sun, 06 Nov 1994 08:49:37 GMT\r\n",
            "\r\n",
        )

        parser = ResponseParser()

        # Act
        dataread(parser, response1)
        dataread(parser, response2)

        # Assert
        @test hascompleteresponse(parser)
    end

    @testset "ResponseParser; Complete response in two parts with excess; The parser has a complete response" begin
        # Arrange
        response1 = todata(
            "HTTP/1.1 101 Switch Protocols\r\n",
        )
        response2 = todata(
            "Date: Sun, 06 Nov 1994 08:49:37 GMT\r\n",
            "\r\n",
            "Some excess data"
        )

        parser = ResponseParser()

        # Act
        dataread(parser, response1)
        dataread(parser, response2)

        # Assert
        @test hascompleteresponse(parser)
    end
end