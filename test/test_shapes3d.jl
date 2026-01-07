using Test
using StaticArrays
using LinearAlgebra
using BallSim
using BallSim.Common
using BallSim.Shapes

# We need to manually include 3D shape definitions if they aren't loaded yet,
# but the plan is to define them in src/Shapes.jl.
# For now, we assume they will be available.

@testset "3D Shapes" begin
    # 1. Circle3D (Sphere)
    @testset "Circle3D" begin
        # Assume Circle3D(radius)
        c = Shapes.Circle3D(2.0f0)

        # Test SDF
        # Inside
        @test Common.sdf(c, SVector(0f0, 0f0, 0f0), 0) ≈ -2.0f0
        @test Common.sdf(c, SVector(1f0, 0f0, 0f0), 0) ≈ -1.0f0
        # On surface
        @test Common.sdf(c, SVector(2f0, 0f0, 0f0), 0) ≈ 0.0f0
        # Outside
        @test Common.sdf(c, SVector(3f0, 0f0, 0f0), 0) ≈ 1.0f0
        @test Common.sdf(c, SVector(0f0, 2f0, 2f0), 0) ≈ (sqrt(8f0) - 2.0f0)

        # Test Normal
        @test Common.normal(c, SVector(3f0, 0f0, 0f0), 0) ≈ SVector(1f0, 0f0, 0f0)
        @test Common.normal(c, SVector(0f0, 3f0, 0f0), 0) ≈ SVector(0f0, 1f0, 0f0)
        @test Common.normal(c, SVector(0f0, 0f0, 3f0), 0) ≈ SVector(0f0, 0f0, 1f0)
    end

    # 2. Inverted Circle3D
    @testset "Inverted Circle3D" begin
        c = Shapes.Circle3D(5.0f0)
        inv_c = Shapes.Inverted(c)

        # Inside original (safe zone for inverted) -> SDF > 0
        # center (dist -5) -> inverted dist +5
        @test Common.sdf(inv_c, SVector(0f0, 0f0, 0f0), 0) ≈ 5.0f0

        # Outside original (collision for inverted) -> SDF < 0
        @test Common.sdf(inv_c, SVector(6f0, 0f0, 0f0), 0) ≈ -1.0f0

        # Normal should be inverted (pointing IN to the center)
        # At (6,0,0), normal of Circle3D is (1,0,0). Inverted normal is (-1,0,0).
        @test Common.normal(inv_c, SVector(6f0, 0f0, 0f0), 0) ≈ SVector(-1f0, 0f0, 0f0)
    end
end
