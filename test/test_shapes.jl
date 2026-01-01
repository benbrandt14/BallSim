using Test
using StaticArrays
using LinearAlgebra
using BallSim
using BallSim.Common
using BallSim.Shapes

include("fixtures.jl")
using .TestFixtures

@testset "Module: Shapes" begin
    @testset "Circle Geometry" begin
        TestFixtures.print_header("Circle(Radius=1.0)")
        c = Shapes.Circle(1.0f0)
        TestFixtures.print_sdf_slice(c)
        TestFixtures.print_vector_field(c)
        @test Common.sdf(c, SVector(0f0, 0f0), 0f0) ≈ -1.0f0
        @test TestFixtures.check_gradients(c, [SVector(0.5f0, 0.5f0), SVector(-0.9f0, 0.1f0)])
    end

    @testset "Box Geometry" begin
        TestFixtures.print_header("Box(Width=1.0, Height=1.0)")
        b = Shapes.Box(1.0f0, 1.0f0)
        TestFixtures.print_sdf_slice(b)
        @test Common.sdf(b, SVector(0f0, 0f0), 0f0) ≈ -0.5f0
        @test TestFixtures.check_gradients(b, [SVector(0.6f0, 0f0), SVector(0f0, 0.4f0)])
    end
end
