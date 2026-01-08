using Test
using BallSim
using StaticArrays
using LinearAlgebra

@testset "3D Shapes" begin
    @testset "Box3D" begin
        # 2x2x2 box centered at origin
        # Half dimensions: 1, 1, 1
        b = BallSim.Shapes.Box3D(2.0f0, 2.0f0, 2.0f0)

        # Inside
        @test BallSim.Common.sdf(b, SVector(0.0f0, 0.0f0, 0.0f0), 0.0f0) ≈ -1.0f0
        @test BallSim.Common.sdf(b, SVector(0.5f0, 0.0f0, 0.0f0), 0.0f0) ≈ -0.5f0
        @test BallSim.Common.sdf(b, SVector(0.9f0, 0.9f0, 0.9f0), 0.0f0) ≈ -0.1f0

        # Surface
        @test BallSim.Common.sdf(b, SVector(1.0f0, 0.0f0, 0.0f0), 0.0f0) ≈ 0.0f0
        @test BallSim.Common.sdf(b, SVector(0.0f0, 1.0f0, 0.0f0), 0.0f0) ≈ 0.0f0
        @test BallSim.Common.sdf(b, SVector(0.0f0, 0.0f0, 1.0f0), 0.0f0) ≈ 0.0f0

        # Outside
        @test BallSim.Common.sdf(b, SVector(2.0f0, 0.0f0, 0.0f0), 0.0f0) ≈ 1.0f0
        @test BallSim.Common.sdf(b, SVector(0.0f0, 3.0f0, 0.0f0), 0.0f0) ≈ 2.0f0

        # Normals
        # Right face
        @test BallSim.Common.normal(b, SVector(1.1f0, 0.0f0, 0.0f0), 0.0f0) ≈ SVector(1.0f0, 0.0f0, 0.0f0)
        # Top face
        @test BallSim.Common.normal(b, SVector(0.0f0, 1.1f0, 0.0f0), 0.0f0) ≈ SVector(0.0f0, 1.0f0, 0.0f0)
        # Front face
        @test BallSim.Common.normal(b, SVector(0.0f0, 0.0f0, 1.1f0), 0.0f0) ≈ SVector(0.0f0, 0.0f0, 1.0f0)

        # Corner (approximate, should point along diagonal)
        n = BallSim.Common.normal(b, SVector(2.0f0, 2.0f0, 2.0f0), 0.0f0)
        @test n ≈ normalize(SVector(1.0f0, 1.0f0, 1.0f0))
    end
end
