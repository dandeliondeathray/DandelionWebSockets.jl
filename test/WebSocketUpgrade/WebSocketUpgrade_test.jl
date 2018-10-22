using Test
using DandelionWebSockets.WebSocketUpgrade
using DandelionWebSockets.WebSocketUpgrade: BadHTTPResponse

todata(xs...) = codeunits(join(xs))

@testset "WebSocketUpgrade       " begin
    @testset "Requirement 3.1-1" begin
        # ## 3.1-1 MUST
        # The version of an HTTP message is indicated by an HTTP-Version field
        # in the first line of the message.
        # HTTP-Version   = "HTTP" "/" 1*DIGIT "." 1*DIGIT

        @testset "HTTP Version; The HTTP-Version field is not the first line; BadHTTPResponse is thrown" begin
            # Arrange
            responsetext = todata(
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "HTTP/1.1    101 Switch Protocols\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            @test_throws BadHTTPResponse parseresponse(parser)
        end

        @testset "HTTP Version; Version is HTTP/1.1; Major is 1 and minor is 1" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.httpversion.major == 1
            @test response.httpversion.minor == 1
        end

        @testset "HTTP Version; Version is HTTP/12.34; Major is 12 and minor is 34" begin
            # Arrange
            responsetext = todata(
                "HTTP/12.34 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.httpversion.major == 12
            @test response.httpversion.minor == 34
        end

        @testset "HTTP Version; The major version is not digits; BadHTTPResponse is thrown" begin
            # Arrange
            responsetext = todata(
                "HTTP/1abc2.34 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            @test_throws BadHTTPResponse parseresponse(parser)
        end

        @testset "HTTP Version; The minor version is not digits; BadHTTPResponse is thrown" begin
            # Arrange
            responsetext = todata(
                "HTTP/12.3abc4 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            @test_throws BadHTTPResponse parseresponse(parser)
        end

        @testset "HTTP Version; The line does not start with HTTP; BadHTTPResponse is thrown" begin
            # Arrange
            responsetext = todata(
                "NOTHTTP/1.1 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            @test_throws BadHTTPResponse parseresponse(parser)
        end

        @testset "HTTP Version; The period is whitespace; BadHTTPResponse is thrown" begin
            # Arrange
            responsetext = todata(
                "HTTP/1 1 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            @test_throws BadHTTPResponse parseresponse(parser)
        end
    end

    @testset "Requirement 3.1-2" begin
        @testset "HTTP Version; Version numbers are separate; Major is 1 and minor is 1" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.httpversion.major == 1
            @test response.httpversion.minor == 1
        end
    end

    @testset "Requirement 3.1-3" begin
        @testset "HTTP Version; Version is HTTP/12.34; Major is 12 and minor is 34" begin
            # Arrange
            responsetext = todata(
                "HTTP/12.34 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.httpversion.major == 12
            @test response.httpversion.minor == 34
        end
    end

    @testset "Requirement 3.1-4" begin
        @testset "HTTP Version; Version is HTTP/012.1; Major is 12" begin
            # Arrange
            responsetext = todata(
                "HTTP/012.1 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.httpversion.major == 12
        end

        @testset "HTTP Version; Version is HTTP/000012.1; Major is 12" begin
            # Arrange
            responsetext = todata(
                "HTTP/000012.1 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.httpversion.major == 12
        end

        @testset "HTTP Version; Version is HTTP/1.0000012; Minor is 12" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.0000012 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.httpversion.minor == 12
        end
    end

    @testset "Requirement 4.1-2" begin
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

    @testset "Requirement 6-1" begin
        # Requirement 6-1
        # After receiving and interpreting a request message, a server responds
        # with an HTTP response message.
        #
        #     Response      = Status-Line               ; Section 6.1
        #                     *(( general-header        ; Section 4.5
        #                     | response-header        ; Section 6.2
        #                     | entity-header ) CRLF)  ; Section 7.1
        #                     CRLF
        #                     [ message-body ]          ; Section 7.2
        # This section tests the validity of the Response grammar, including reading all headers.
        # Finding the boundary is tested by requirement 4.1-2.

        @testset "Header fields; First field is Date; Response has the field Date with the right date" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 200 OK\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test findheaderfield(response, "Date") == "Sun, 06 Nov 1998 08:49:37 GMT"
        end

        @testset "Header fields; ETag field has value xyzzy; Response has the field ETag with value xyzzy" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 200 OK\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "ETag: xyzzy\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test findheaderfield(response, "ETag") == "xyzzy"
        end

        @testset "Header fields; No ETag field; findheaderfield returns nothing" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 200 OK\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test findheaderfield(response, "ETag") == nothing
        end

        @testset "Header fields; X-MyHeader with value Foo; Response has the field X-MyHeader with value Foo" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 200 OK\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "ETag: xyzzy\r\n",
                "X-MyHeader: Foo\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test findheaderfield(response, "X-MyHeader") == "Foo"
        end
    end

    @testset "Requirement 6.1-1" begin
        # Requirement 6.1-1
        # The first line of a Response message is the Status-Line, consisting
        # of the protocol version followed by a numeric status code and its
        # associated textual phrase, with each element separated by SP
        # characters. No CR or LF is allowed except in the final CRLF sequence.
        #
        #     Status-Line = HTTP-Version SP Status-Code SP Reason-Phrase CRLF
        #
        # This section tests the validation of the Status-Line as a whole.
        # Requirement 6.1-2 tests the Status-Code.
        # Requirement 6.1-3 tests the Reason-Phrase.
        # Requirement 3.1-1 tests the HTTP Version field.
        # Requirement 4.1-2 tests the boundary between the message header and the body.
        #
        # NOTE: Requirement 3.1-1 deals only with the HTTP-Version field, both for requests and
        #       responses. The tests however deal only with responses. This should perhaps be
        #       restructured later on.
        @testset "Validation; Malformed Status Line; BadHTTPResponse is thrown" begin
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

        @testset "Validation; Status code is not an integer; BadHTTPResponse is thrown" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 ABC OK\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            @test_throws BadHTTPResponse parseresponse(parser)
        end

        @testset "Validation; Reason Phrase is missing; BadHTTPResponse is thrown" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 200\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            @test_throws BadHTTPResponse parseresponse(parser)
        end

        @testset "Validation; HTTP Version is missing; BadHTTPResponse is thrown" begin
            # Arrange
            responsetext = todata(
                "200 OK\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            @test_throws BadHTTPResponse parseresponse(parser)
        end

        # I believe it is syntactically correct to have zero headers in the response.
        @testset "Validation; Status is 200 and no headers; Response is ok and status is 200" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 200 OK\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.status == 200
        end
    end

    @testset "Requirement 6.1-2" begin
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

        @testset "Status Line; Multiple spaces before status code 101; Status code is 101" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1    101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.status == 101
        end

        # TODO: Test that the status is exactly three digits
    end

    @testset "Requirement 6.1-3" begin
        @testset "Status Line; Reason Phrase is 'Switch Protocols' in header; Response has Reason Phrase 'Switch Protocols'" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 101 Switch Protocols\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.reasonphrase == "Switch Protocols"
        end

        @testset "Status Line; Reason Phrase is 'OK' in header; Response has Reason Phrase 'OK'" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 200 OK\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.reasonphrase == "OK"
        end

        @testset "Status line; Multiple spaces before Reason Phrase; Spaces are trimmed" begin
            # Arrange
            responsetext = todata(
                "HTTP/1.1 200        OK\r\n",
                "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
                "\r\n",
            )

            parser = ResponseParser()
            dataread(parser, responsetext)

            # Act
            response = parseresponse(parser)

            # Assert
            @test response.reasonphrase == "OK"
        end
    end

    @testset "Requirement 6.2-1" begin
    end

    @testset "Requirement 14.10-3" begin
        # TODO Mark some requirements 14.10-* as inapplicable.
    end

    @testset "Requirement 14.42-5" begin
        # TODO Even when the Connection field has more than one token?
        # TODO Test that an Upgrade field with a Connection field works
        # TODO Test that an Upgrade field can have more than one token
        # TODO Test that the order between tokens is maintained

        # TODO Test that an Upgrade field without a Connection field containing "upgrade" fails
        # @testset "Upgrade field; No Connection field; InvalidHTTPResponse is thrown" begin
        #     # Arrange
        #     responsetext = todata(
        #         "HTTP/1.1 200        OK\r\n",
        #         "Date: Sun, 06 Nov 1998 08:49:37 GMT\r\n",
        #         "Upgrade: websocket"
        #         "\r\n",
        #     )

        #     parser = ResponseParser()
        #     dataread(parser, responsetext)

        #     # Act
        #     @test_throws InvalidHTTPResponse parseresponse(parser)
        # end
    end
end