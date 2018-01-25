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
    end
end
