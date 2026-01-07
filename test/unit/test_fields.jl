using Test
using BallSim.Common
using BallSim.Fields
using StaticArrays
using LinearAlgebra

@testset "Physics Fields" begin
    
    # Mock particle state
    p = SVector(1.0f0, 0.0f0)
    v = SVector(0.0f0, 10.0f0)
    m = 2.0f0
    t = 0.0f0
    
    @testset "Uniform Field" begin
        g = SVector(0.0f0, -9.8f0)
        field = Fields.UniformField(g)
        # Uniform field now returns Force = m * g
        @test field(p, v, m, t) == g * m
    end
    
    @testset "Drag Field" begin
        # F = -k * v
        k = 0.5f0
        field = Fields.ViscousDrag(k)
        expected = -k * v
        @test field(p, v, m, t) ≈ expected
    end
    
    @testset "Central Field (Gravity/Magnetism)" begin
        # F = strength * normalize(center - p) / dist^2 (Simplified or specific mode)
        # Let's test a simple attractor
        center = SVector(0.0f0, 0.0f0)
        strength = 10.0f0 # Attractive
        field = Fields.CentralField(center, strength, mode=:attractor)
        
        # At (1,0), direction to center is (-1,0). Dist is 1.
        # F = 10 * (-1,0)
        # Central field returns F = (dir * mag) * m
        @test field(p, v, m, t) ≈ SVector(-10.0f0, 0.0f0) * m
    end
    
    @testset "Combined Field" begin
        # F_total = Gravity + Wind
        g = Fields.UniformField(SVector(0f0, -10f0))
        w = Fields.UniformField(SVector(5f0, 0f0))
        
        combo = Fields.CombinedField((g, w))
        
        @test combo(p, v, m, t) ≈ SVector(5.0f0, -10.0f0) * m
    end
end