using DandelionWebSockets.UniformResourceIdentifiers

@testset "Requirement 3.2-7" begin
    @testset "Port is not given; Scheme is http; Port is 80" begin
        # Act
        uri = URI("http://host/")

        # Assert
        @test uri.port == 80
    end

    @testset "Port is empty; Scheme is http; Port is 80" begin
        # Act
        uri = URI("http://host:/")

        # Assert
        @test uri.port == 80
    end

    @testset "Port is not given; Scheme is ws; Port is 80" begin
        # Act
        uri = URI("ws://host/")

        # Assert
        @test uri.port == 80
    end

    @testset "Port is not given; Scheme is wss; Port is 443" begin
        # Act
        uri = URI("wss://host/")

        # Assert
        @test uri.port == 443
    end

    @testset "Port is empty; Scheme is wss; Port is 443" begin
        # Act
        uri = URI("wss://host:/")

        # Assert
        @test uri.port == 443
    end
end