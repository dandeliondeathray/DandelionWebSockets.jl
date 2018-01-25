using Base.Test
using DandelionWebSockets: HandshakeResult, validate

@testset "Handshake            " begin
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
end
