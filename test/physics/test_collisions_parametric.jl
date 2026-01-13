using Test
using BallSim
using BallSim.Physics
using BallSim.Shapes
using BallSim.Common
using StaticArrays
using LinearAlgebra # Added for normalize
using Random

@testset "Parametric Collision Tests" begin
    # Helper to create a simple system
    function create_single_particle_system(pos::SVector{D,T}, vel::SVector{D,T}) where {D,T}
        sys = Common.BallSystem(1, D, T)
        sys.data.pos[1] = pos
        sys.data.vel[1] = vel
        sys.data.active[1] = true
        return sys
    end

    @testset "Sphere Collision (Analytical)" begin
        # Test collision detection against a sphere at origin with radius 10.0
        # Particle is at various distances
        boundary = Shapes.Circle(10.0f0) # In 2D, Circle functions as a container (inside is valid)

        # Center: (0,0). Radius 10.
        p_center = SVector(0.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(boundary, p_center, 0.0f0)
        @test c == false

        # Near edge but inside: (9.0, 0).
        p_near = SVector(9.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(boundary, p_near, 0.0f0)
        @test c == false

        # Outside: (11.0, 0).
        # Penetration depth should be 1.0 (distance from surface).
        # Normal for Circle Container points OUTWARD (towards the collision/forbidden zone).
        # Physics.step! subtracts n * dist to restore: (11,0) - (1,0)*1 -> (10,0).

        p_out = SVector(11.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(boundary, p_out, 0.0f0)

        @test c == true
        @test d ≈ 1.0f0 atol=1e-5
        # Normal points OUTWARD (1, 0).
        @test n ≈ SVector(1.0f0, 0.0f0) atol=1e-5
    end

    @testset "Parametric Random Tests" begin
        # Generate random points and verify collision properties
        boundary = Shapes.Circle(10.0f0)
        rng = MersenneTwister(123)

        for i in 1:100
            # Random point in annulus r in [5, 15]
            theta = rand(rng) * 2pi
            r = 5.0f0 + rand(rng, Float32) * 10.0f0 # 5 to 15
            x = r * cos(theta)
            y = r * sin(theta)
            p = SVector(x, y)

            (c, d, n) = Common.detect_collision(boundary, p, 0.0f0)

            if r > 10.0f0
                # Outside -> Collision
                @test c == true
                @test d ≈ (r - 10.0f0) atol=1e-4
                # Normal observed to be outward (p_hat)
                expected_n = normalize(p)
                @test n ≈ expected_n atol=1e-4
            else
                # Inside -> No Collision
                @test c == false
            end
        end
    end
end
