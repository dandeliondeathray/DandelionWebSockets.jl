using Test
using DandelionWebSockets.WebSocketUpgrade
using DandelionWebSockets.WebSocketUpgrade: BadHTTPResponse

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

    @testset "ResponseParser; Response with status code 101; Parse result has status 101" begin
        # Arrange
        responsetext = todata(
            "HTTP/1.1 101 Switch Protocols\r\n",
            "Date: Sun, 06 Nov 1994 08:49:37 GMT\r\n",
            "\r\n",
        )

        parser = ResponseParser()
        dataread(parser, responsetext)

        # Act
        response = parseresponse(parser)

        # Assert
        @test response.status == 101
    end

    @testset "ResponseParser; Response with status code 200; Parse result has status 200" begin
        # Arrange
        responsetext = todata(
            "HTTP/1.1 200 OK\r\n",
            "Date: Sun, 06 Nov 1994 08:49:37 GMT\r\n",
            "\r\n",
        )

        parser = ResponseParser()
        dataread(parser, responsetext)

        # Act
        response = parseresponse(parser)

        # Assert
        @test response.status == 200
    end


    @testset "ResponseParser; Status code is 101 and year is 200x; Parse result has status 101" begin
        # Arrange
        responsetext = todata(
            "HTTP/1.1 101 Switch Protocols\r\n",
            "Date: Sun, 06 Nov 2008 08:49:37 GMT\r\n",
            "\r\n",
        )

        parser = ResponseParser()
        dataread(parser, responsetext)

        # Act
        response = parseresponse(parser)

        # Assert
        @test response.status == 101
    end

    # TODO: Test spacing in the status line

    @testset "ResponseParser; Malformed Status Line; BadHTTPResponse is thrown" begin
        # Arrange
        responsetext = todata(
            "Malformed HTTP header",
            "Date: Sun, 06 Nov 1994 08:49:37 GMT\r\n",
            "\r\n",
        )

        parser = ResponseParser()
        dataread(parser, responsetext)

        # Act
        @test_throws BadHTTPResponse parseresponse(parser)
    end
end