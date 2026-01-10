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
        center = SVector(0.0f0, 0.0f0)
        strength = 10.0f0

        @testset "Attractor Mode" begin
            field = Fields.CentralField(center, strength, mode = :attractor)

            # At (1,0), direction to center is (-1,0). Dist is 1.
            # F = 10 * (-1,0)
            # Central field returns F = (dir * mag) * m
            @test field(p, v, m, t) ≈ SVector(-10.0f0, 0.0f0) * m
        end

        @testset "Repulsor Mode" begin
            field = Fields.CentralField(center, strength, mode = :repulsor)

            # At (1,0), direction from center is (1,0). Dist is 1.
            # F = 10 * (1,0)
            @test field(p, v, m, t) ≈ SVector(10.0f0, 0.0f0) * m
        end

        @testset "Inverse Square Law Verification" begin
            field = Fields.CentralField(center, strength, mode = :attractor, cutoff = 0.0f0)

            p1 = SVector(2.0f0, 0.0f0)
            f1 = field(p1, v, m, t)

            p2 = SVector(4.0f0, 0.0f0)
            f2 = field(p2, v, m, t)

            # Distance doubled, force should be 1/4
            # We compare magnitudes
            @test isapprox(norm(f2), norm(f1) / 4.0f0, atol = 1e-5)
        end

        @testset "Cutoff / Singularity Avoidance" begin
            cutoff = 0.5f0
            field =
                Fields.CentralField(center, strength, mode = :attractor, cutoff = cutoff)

            # Point inside cutoff
            p_inner = SVector(0.1f0, 0.0f0)

            # Force should use cutoff distance for magnitude calculation
            # mag = strength / cutoff^2
            # dir = diff / cutoff (normalized relative to cutoff scale? No, dir = diff / denom where denom=cutoff)
            # Wait, implementation: dir = diff / denom. If denom=cutoff, dir is SCALED DOWN.
            # force = dir * mag * m = (diff / cutoff) * (strength / cutoff^2) * m

            f_inner = field(p_inner, v, m, t)

            expected_mag = (strength / (cutoff^2))
            # But the direction vector is `diff / cutoff`. Length is 0.1 / 0.5 = 0.2.
            # So actual force magnitude = 0.2 * expected_mag * m

            # Let's verify exactly
            diff = center - p_inner # (-0.1, 0)
            denom = max(norm(diff), cutoff) # 0.5
            dir = diff / denom # (-0.1/0.5, 0) = (-0.2, 0)
            mag = strength / (denom^2) # 10 / 0.25 = 40
            expected_force = dir * mag * m # (-0.2, 0) * 40 * 2 = (-8, 0) * 2 = (-16, 0)

            @test f_inner ≈ expected_force

            # Ensure it doesn't explode at 0
            p_zero = SVector(0.0f0, 0.0f0)
            f_zero = field(p_zero, v, m, t)
            @test f_zero == SVector(0.0f0, 0.0f0)
        end
    end

    @testset "Combined Field" begin
        # F_total = Gravity + Wind
        g = Fields.UniformField(SVector(0.0f0, -10.0f0))
        w = Fields.UniformField(SVector(5.0f0, 0.0f0))

        combo = Fields.CombinedField((g, w))

        @test combo(p, v, m, t) ≈ SVector(5.0f0, -10.0f0) * m
    end
end
