using Test
using DandelionWebSockets:
    HandshakeResult, validate, convert_ws_uri, HeaderList, HTTPHandshake, performhandshake
import DandelionWebSockets: dohandshake

mutable struct MockHTTP <: DandelionWebSockets.HTTPAdapter
    sentheaders::AbstractVector{HeaderList}

    MockHTTP() = new([])
end

dohandshake(m::MockHTTP, headers::HeaderList) = push!(m.sentheaders, headers)

@testset "Handshake              " begin
    @testset "validate a handshake" begin
        @testset "the handshake is valid" begin
            headers = Dict(
                "Sec-WebSocket-Accept" => "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
            )

            handshake_result = HandshakeResult(
                "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",
                IOBuffer(),
                headers,
                [])

            @test validate(handshake_result) == true
        end

        @testset "mismatching Sec-WebSocket-Accept header field; validatio fails" begin
            """
            # Requirement
            @4_1_HandshakeResponse_4
            """
            headers = Dict(
                "Sec-WebSocket-Accept" => "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
            )

            handshake_result = HandshakeResult(
                "thisdoesnotmatchsecwebsocketaccept",
                IOBuffer(),
                headers,
                [])

            @test validate(handshake_result) == false
        end

        @testset "missing Sec-WebSocket-Accept header field; validation fails" begin
            """
            # Requirement
            @4_1_HandshakeResponse_4
            """
            headers = Dict()

            handshake_result = HandshakeResult(
                "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",
                IOBuffer(),
                headers,
                [])

            @test validate(handshake_result) == false
        end

        @testset "Sec-WebSocket-Key calculation example from the specification 4.1 entry 7, handshake section" begin
            nonce = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
            sec_websocket_key = DandelionWebSockets.make_websocket_key(nonce)
            @test sec_websocket_key == "AQIDBAUGBwgJCgsMDQ4PEA=="
        end

        @testset "Example calculation of accept key, section 4.2.2" begin
            key = "dGhlIHNhbXBsZSBub25jZQ=="
            @test DandelionWebSockets.calculate_accept(key) == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
        end
    end

    @testset "Client side handshake headers" begin
        @testset "Sec-WebSocket-Version field must be 13" begin
            """
            # Requirement
            @4_1_OpeningHandshake_9
            """
            headers = DandelionWebSockets.make_headers("")
            @test headers["Sec-WebSocket-Version"] == "13"
        end

        @testset "Upgrade field must be websocket" begin
            """
            # Requirement
            @4_1_OpeningHandshake_5
            """
            headers = DandelionWebSockets.make_headers("")
            @test headers["Upgrade"] == "websocket"
        end

        @testset "Connection field must be Upgrade" begin
            """
            # Requirement
            @4_1_OpeningHandshake_6
            """
            headers = DandelionWebSockets.make_headers("")
            @test headers["Connection"] == "Upgrade"
        end

        @testset "Sec-WebSocket-Key must match supplied key" begin
            """
            # Requirement
            @4_1_OpeningHandshake_7-1
            """
            key = "Some key value"
            headers = DandelionWebSockets.make_headers(key)
            @test headers["Sec-WebSocket-Key"] == key
        end
    end

    @testset "Convert URIs from ws:// to http://" begin
        # Requirement
        # @4_1_EstablishConnection_5-1
        #
        # This covers the above requirement with the additional information that we use HTTP.jl
        # for making the connection, and that is what _actually_ covers the requirement.
        @test convert_ws_uri("ws://some/uri") == "http://some/uri"
        @test convert_ws_uri("wss://some/uri") == "https://some/uri"
        @test convert_ws_uri("http://some/uri") == "http://some/uri"
    end

    @testset "Case insensitive headers in validation" begin
        handshake_result_with_accept(accept_header_name::String) = HandshakeResult(
            "expected accept key",
            IOBuffer(),
            Dict(accept_header_name => "expected accept key"),
            [])

        @testset "all lowercase name" begin
            @test validate(handshake_result_with_accept("sec-websocket-accept")) == true
        end

        @testset "all uppercase name" begin
            @test validate(handshake_result_with_accept("SEC-WEBSOCKET-ACCEPT")) == true
        end

        @testset "mixed case" begin
            @test validate(handshake_result_with_accept("SEC-websocket-ACCEPT")) == true
        end
    end

    @testset "New handshake" begin
        @testset "Do a handshake; An HTTP request is sent" begin
            # Arrange
            rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
            mockhttp = MockHTTP()
            h = HTTPHandshake(rng, mockhttp)

            # Act
            performhandshake(h)

            # Assert
            @test length(mockhttp.sentheaders) == 1
        end
    end
end
