using Test
using BallSim
using StaticArrays
using LinearAlgebra

@testset "Polygon 2D" begin
    # Triangle: (0,0), (2,0), (1,1)
    v1 = SVector(0.0f0, 0.0f0)
    v2 = SVector(2.0f0, 0.0f0)
    v3 = SVector(1.0f0, 1.0f0)
    poly = Shapes.Polygon(SVector(v1, v2, v3))

    # Inside (Centroid approx: 1, 0.33)
    p_in = SVector(1.0f0, 0.3f0)
    sdf_in = Common.sdf(poly, p_in, 0.0f0)
    @test sdf_in < 0.0f0

    (collided, dist, n) = Common.detect_collision(poly, p_in, 0.0f0)
    @test !collided # Inside is safe

    # Outside
    p_out = SVector(1.0f0, 2.0f0) # Above top vertex
    sdf_out = Common.sdf(poly, p_out, 0.0f0)
    @test sdf_out > 0.0f0

    (collided, dist, n) = Common.detect_collision(poly, p_out, 0.0f0)
    @test collided
    @test dist > 0.0f0
    # Normal should point UP (0,1) roughly
    @test n[2] > 0.9f0
end

@testset "Rotating Boundary" begin
    # Rectangle: Width 4, Height 2. x in [-2,2], y in [-1,1]
    rect = Shapes.Box(4.0f0, 2.0f0)
    rot_rect = Shapes.Rotating(rect, Float32(pi/2)) # 90 deg/s

    # t=1.0. Rotated 90 deg.
    # Now width is aligned with Y axis. x in [-1,1], y in [-2,2].

    p_check = SVector(1.5f0, 0.0f0)

    # Check at t=0: p_check is INSIDE (x < 2)
    @test Common.sdf(rect, p_check, 0.0f0) < 0
    (c0, d0, n0) = Common.detect_collision(rot_rect, p_check, 0.0f0)
    @test !c0

    # Check at t=1: Rotated 90 deg.
    # The point p_check=(1.5,0) is fixed in world.
    # The shape is now tall and thin (width 2 along X).
    # Bounds: x in [-1, 1].
    # So p_check(1.5) is OUTSIDE.

    (c1, d1, n1) = Common.detect_collision(rot_rect, p_check, 1.0f0)
    @test c1
    # Normal should be along X (1,0)
    @test abs(n1[1]) > 0.9f0
end

@testset "VortexField" begin
    vf = Fields.VortexField(SVector(0.0f0, 0.0f0), 10.0f0)

    # At (1,0), force should be up (0,1) * 10/1^2 = (0,10)
    f = vf(SVector(1.0f0, 0.0f0), SVector(0f0,0f0), 1.0f0, 0.0f0)
    @test isapprox(f[1], 0.0f0; atol=1e-4)
    @test isapprox(f[2], 10.0f0; atol=1e-4)

    # At (0,1), force should be left (-1,0) * 10
    f2 = vf(SVector(0.0f0, 1.0f0), SVector(0f0,0f0), 1.0f0, 0.0f0)
    @test isapprox(f2[1], -10.0f0; atol=1e-4)
    @test isapprox(f2[2], 0.0f0; atol=1e-4)
end
