using Test
using BallSim.Common
using BallSim.Shapes
using StaticArrays
using LinearAlgebra

@testset "Inverted Shapes Logic" begin

    @testset "Inverted Box" begin
        # Box is typically a Container (Particles trapped inside).
        # Inverted Box becomes an Obstacle (Particles bounce off outside).

        # NOTE: Shapes.jl implementation of Inverted uses `-sdf(inner)`.
        # Box SDF: Negative Inside, Positive Outside.
        # Inverted Box SDF: Positive Inside (Safe), Negative Outside (Collision).
        # Wait, usually SDF < 0 is Collision?
        # In `detect_collision`: "if dist > 0 ... return true".
        # So "Collision" is Positive.
        # Box: Outside is Positive (Collision). Inside is Negative (Safe).
        # Inverted Box: Outside is Negative (Safe). Inside is Positive (Collision).

        # Wait, if Inverted Box is an OBSTACLE:
        # We want particles to be safe OUTSIDE.
        # So Outside must be Safe (Negative or <= 0).
        # Inside must be Collision (Positive).

        # Let's check `sdf(Inverted)`: `return -Common.sdf(b.inner, p, t)`
        # Box SDF (Inner):
        #   Outside (e.g. 10,0 for 2x2 box): Positive.
        #   Inside (0,0): Negative.

        # Inverted Box SDF:
        #   Outside: Negative. (Safe? Yes, if detect checks > 0).
        #   Inside: Positive. (Collision? Yes).

        # So Inverted(Box) works as an OBSTACLE.

        inner_box = Shapes.Box(2.0f0, 2.0f0) # Bounds +/- 1
        inv_box = Shapes.Inverted(inner_box)

        # Point Inside (0,0) -> Should collide
        p_in = SVector(0.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(inv_box, p_in, 0.0f0)
        @test c == true
        @test d > 0
        # Normal should push OUT to safe zone (Outside).
        # Box normal at (0,0) depends on implementation (usually unit X or Y).
        # Inverted normal = -BoxNormal.

        # Point Outside (2,0) -> Should be safe
        p_out = SVector(2.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(inv_box, p_out, 0.0f0)
        @test c == false
    end

    @testset "Inverted Ellipsoid" begin
        ell = Shapes.Ellipsoid(2.0f0, 1.0f0)
        inv_ell = Shapes.Inverted(ell)

        # Inside (0,0) -> Collision
        p_in = SVector(0.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(inv_ell, p_in, 0.0f0)
        @test c == true

        # Outside (3,0) -> Safe
        p_out = SVector(3.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(inv_ell, p_out, 0.0f0)
        @test c == false
    end
end
