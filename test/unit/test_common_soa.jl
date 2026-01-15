using Test
using BallSim
using BallSim.Common
using StaticArrays

@testset "Common SoA Data Layout" begin

    @testset "BallSystem Iterator" begin
        # Create a system with 10 particles
        N = 10
        # BallSystem(N, D, T)
        sys = Common.BallSystem(N, 2, Float32)

        # Activate even particles
        for i in 1:N
            sys.data.active[i] = (i % 2 == 0)
            sys.data.pos[i] = SVector{2,Float32}(i, i)
        end

        count = 0
        sum_pos_x = 0.0f0

        # Iterate manually as one would in a kernel or loop
        for i in 1:length(sys.data.pos)
            if sys.data.active[i]
                count += 1
                sum_pos_x += sys.data.pos[i][1]
            end
        end

        @test count == 5
        # Sum of even numbers 2+4+6+8+10 = 30
        @test sum_pos_x == 30.0f0
    end

    @testset "Reset System" begin
        sys = Common.BallSystem(5, 2, Float32)
        sys.data.active .= true

        # Hypothetical reset function or manual reset
        fill!(sys.data.active, false)

        @test !any(sys.data.active)
    end
end
