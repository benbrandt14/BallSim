using Test
using BallSim
using BallSim.Common
using StaticArrays

@testset "BallSystem Edge Cases" begin
    @testset "Constructor" begin
        # Normal construction
        sys = Common.BallSystem(10, 2)
        @test length(sys.data.pos) == 10
        @test length(sys.data.vel) == 10

        # Zero particles - allowed but edge case
        sys_zero = Common.BallSystem(0, 2)
        @test length(sys_zero.data.pos) == 0

        # Negative particles should throw or handle (Julia arrays throw on negative size)
        @test_throws ArgumentError Common.BallSystem(-1, 2)

        # 3D System
        sys3d = Common.BallSystem(5, 3)
        @test sys3d.data.pos[1] isa SVector{3, Float32}

        # Double precision
        sys_f64 = Common.BallSystem(5, 2, Float64)
        @test sys_f64.data.pos[1] isa SVector{2, Float64}
        @test eltype(sys_f64.data.mass) == Float64
    end
end
