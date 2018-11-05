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

    @testset "Good enough URI; Scheme is ws; Parse is correct" begin
        # Act
        uri = URI("ws://hostname:42/abs/path")

        # Assert
        @test uri.scheme == "ws"
        @test uri.host == "hostname"
        @test uri.port == 42
        @test uri.abs_path == "/abs/path"
    end

    @testset "Good enough URI; No abs_path; abs_path is /" begin
        # Act
        uri = URI("ws://hostname:42")

        # Assert
        @test uri.abs_path == "/"
    end

    @testset "Good enough URI: Scheme is wss; issecure is true" begin
        # Act
        uri = URI("wss://hostname:42/abs/path")

        # Assert
        @test uri.issecure
    end

    @testset "Good enough URI: Scheme is ws; issecure is false" begin
        # Act
        uri = URI("ws://hostname:42/abs/path")

        # Assert
        @test !uri.issecure
    end

    @testset "Good enough URI: Scheme is http; issecure is false" begin
        # Act
        uri = URI("http://hostname:42/abs/path")

        # Assert
        @test !uri.issecure
    end

    @testset "Good enough URI: Scheme is https; issecure is true" begin
        # Act
        uri = URI("https://hostname:42/abs/path")

        # Assert
        @test uri.issecure
    end
end