using Test
using DandelionWebSockets:
    HeaderList, HTTPHandshake, performhandshake,
    issuccessful, HTTPUpgradeResponse
import DandelionWebSockets: dohandshake

mutable struct MockHTTP <: DandelionWebSockets.HTTPAdapter
    sentheaders::AbstractVector{HeaderList}
    senturis::AbstractVector{String}
    accept::String
    status::Int
    io::IO
    excess::AbstractVector{UInt8}
    ex::Union{Exception, Nothing}

    MockHTTP(;
             accept::String = "C/0nmHhBztSRGR1CwL6Tf4ZjwpY=",
             status::Int = 101,
             excess::AbstractVector{UInt8} = b"",
             io::IO = IOBuffer(),
             ex::Union{Exception,Nothing} = nothing) = new([], [], accept, status, io, excess, ex)
end

function dohandshake(m::MockHTTP, uri::String, headers::HeaderList) :: HTTPUpgradeResponse
    push!(m.sentheaders, headers)
    push!(m.senturis, uri)
    if m.ex != nothing
        throw(m.ex)
    end
    HTTPUpgradeResponse(m.io, m.status, [
        "Sec-WebSocket-Accept" => m.accept,
        "Connection" => "Upgrade",
        "Upgrade" => "websocket"],
        m.excess)
end

@testset "Handshake              " begin
    @testset "New handshake" begin
        @testset "Do a handshake; An HTTP request is sent" begin
            # Arrange
            rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
            mockhttp = MockHTTP()
            h = HTTPHandshake(rng, mockhttp)

            # Act
            performhandshake(h, "ws://some/uri")

            # Assert
            @test length(mockhttp.sentheaders) == 1
        end

        @testset "Do a handshake; The URI is the same as provided to performhandshake" begin
            # Arrange
            rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
            mockhttp = MockHTTP()
            h = HTTPHandshake(rng, mockhttp)

            # Act
            performhandshake(h, "ws://some/uri")

            # Assert
            @test mockhttp.senturis[1] == "ws://some/uri"
        end

        @testset "Do a handshake; Standard WebSocket headers are present in the HTTP request" begin
            # Arrange
            rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
            mockhttp = MockHTTP()
            h = HTTPHandshake(rng, mockhttp)

            # Act
            performhandshake(h, "ws://some/uri")

            # Assert
            headers = Dict{String, String}(mockhttp.sentheaders[1])
            @test haskey(headers, "Sec-WebSocket-Key")
            @test haskey(headers, "Sec-WebSocket-Version")
            @test haskey(headers, "Upgrade")
            @test haskey(headers, "Connection")
        end

        @testset "Do a valid handshake; The handshake is successful" begin
            # Arrange
            # These fake random values generates the default accept value for MockHTTP, so this is
            # a valid handshake.
            rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
            mockhttp = MockHTTP()
            h = HTTPHandshake(rng, mockhttp)

            # Act
            handshakeresult = performhandshake(h, "ws://some/uri")

            # Assert
            @test issuccessful(handshakeresult)
        end

        @testset "Do an invalid handshake; The handshake is unsuccessful" begin
            # Arrange
            rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
            invalidstatuscode = 200
            mockhttp = MockHTTP(status = invalidstatuscode)
            h = HTTPHandshake(rng, mockhttp)

            # Act
            handshakeresult = performhandshake(h, "ws://some/uri")

            # Assert
            @test !issuccessful(handshakeresult)
        end

        @testset "The upgraded socket has bytes available; Those bytes can be read in the handshake result" begin
            # Arrange
            # These fake random values generates the default accept value for MockHTTP, so this is
            # a valid handshake.
            rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
            mockhttp = MockHTTP(io = IOBuffer(b"\x01\x02\x03"))
            h = HTTPHandshake(rng, mockhttp)

            # Act
            handshakeresult = performhandshake(h, "ws://some/uri")

            # Assert
            @test readavailable(handshakeresult.io) == b"\x01\x02\x03"
        end

        @testset "Do a valid handshake with excess bytes read; The excess bytes are returned in the handshake result" begin
            # Arrange
            rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
            mockhttp = MockHTTP(; excess = b"\xca\xfe\xba\xbe")
            h = HTTPHandshake(rng, mockhttp)

            # Act
            handshakeresult = performhandshake(h, "ws://some/uri")

            # Assert
            @test handshakeresult.excess == b"\xca\xfe\xba\xbe"
        end

        @testset "The HTTPAdapter throws an exception; The handshake is not successful" begin
            # Arrange
            rng = FakeRNG{UInt8}(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10")
            mockhttp = MockHTTP(ex=EOFError())
            h = HTTPHandshake(rng, mockhttp)

            # Act
            handshakeresult = performhandshake(h, "ws://some/uri")

            # Assert
            @test !issuccessful(handshakeresult)
        end
    end
end
