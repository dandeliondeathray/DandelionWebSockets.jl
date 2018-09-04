using Test
using .Stubs

@testset "InProcessIO" begin
    @testset "Write 1-5 on endpoint 1; Can read 1-5 on endpoint 2" begin
        iopair = InProcessIOPair()
        readvalues = UInt8[]
        @sync begin
            @async begin
                for i = 1:5
                    write(iopair.endpoint1, UInt8(i))
                end
            end

            @async begin
                for i = 1:5
                    x = read(iopair.endpoint2, UInt8)
                    push!(readvalues, x)
                end
            end
        end

        @test readvalues == UInt8[1, 2, 3, 4, 5]
    end

    @testset "Write 1-5 on endpoint 1, and 100-110 on endpoint 2; Values can be read independently" begin
        iopair = InProcessIOPair()
        readon1 = UInt8[]
        readon2 = UInt8[]
        @sync begin
            @async begin
                for i = 1:5
                    write(iopair.endpoint1, UInt8(i))
                end
                close(iopair.endpoint1)
            end

            @async begin
                for i = 100:110
                    write(iopair.endpoint2, UInt8(i))
                end
                close(iopair.endpoint2)
            end

            @async begin
                try
                    while true
                        x = read(iopair.endpoint1, UInt8)
                        push!(readon1, x)
                    end
                catch ex
                    if typeof(ex) != EOFError
                        rethrow()
                    end
                end
            end

            @async begin
                try
                    while true
                        x = read(iopair.endpoint2, UInt8)
                        push!(readon2, x)
                    end
                catch ex
                    if typeof(ex) != EOFError
                        rethrow()
                    end
                end
            end
        end

        @test readon1 == UInt8[100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
        @test readon2 == UInt8[1, 2, 3, 4, 5]
    end

    @testset "Send 5 values, and then close endpoint 1; EOF is reported on endpoint 2 after 5 values" begin
        iopair = InProcessIOPair()
        readvalues = []
        for i = 1:5
            write(iopair.endpoint1, UInt8(i))
        end
        close(iopair.endpoint1)

        for i = 1:5
            x = read(iopair.endpoint2, UInt8)
            push!(readvalues, x)
        end

        @test readvalues == UInt8[1, 2, 3, 4, 5]
        @test eof(iopair.endpoint2)
    end

    @testset "Send 5 values, and then close endpoint 1; EOF is not reported on endpoint 2 until after 5 values have been read" begin
        iopair = InProcessIOPair()
        for i = 1:5
            write(iopair.endpoint1, UInt8(1))
        end
        close(iopair.endpoint1)

        for i = 1:5
            @test !eof(iopair.endpoint2)
            read(iopair.endpoint2, UInt8)
        end
    end
end