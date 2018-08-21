using DandelionWebSockets: HTTPHandshakeLogic, getrequestheaders

@testset "Handshake logic        " begin
    @testset "Sec-WebSocket-Version; Version is 13" begin
        rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
        h = HTTPHandshakeLogic(rng)

        headers = getrequestheaders(h)
        headersdict = Dict(headers)

        @test headersdict["Sec-WebSocket-Version"] == "13"
    end

    @testset "Upgrade header; Upgrade header is 'websocket'" begin
        rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
        h = HTTPHandshakeLogic(rng)

        headers = getrequestheaders(h)
        headersdict = Dict(headers)

        @test headersdict["Upgrade"] == "websocket"
    end

    @testset "Connection header; Has value 'Upgrade'" begin
        rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
        h = HTTPHandshakeLogic(rng)

        headers = getrequestheaders(h)
        headersdict = Dict(headers)

        @test headersdict["Connection"] == "Upgrade"
    end
end