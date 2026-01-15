using Test
using BallSim
using StaticArrays
using LinearAlgebra

@testset "Demo Features" begin

    @testset "ConvexPolygon" begin
        # Triangle (Counter-Clockwise)
        # (0,0) -> (2,0) -> (0,2)
        p1 = SVector(0.0f0, 0.0f0)
        p2 = SVector(2.0f0, 0.0f0)
        p3 = SVector(0.0f0, 2.0f0)

        poly = Shapes.ConvexPolygon([p1, p2, p3])

        # 1. Inside Point (0.5, 0.5)
        c = SVector(0.5f0, 0.5f0)
        d = Common.sdf(poly, c, 0.0f0)
        # Distance to edges:
        # Edge 1 (y=0): 0.5
        # Edge 2 (y = -x + 2): dist = (x+y-2)/sqrt(2) = (1-2)/1.414 = -0.707
        # Edge 3 (x=0): 0.5
        # Max is negative?
        # Wait, normals point OUTWARD.
        # Edge 1: (0,0)->(2,0). dy=0, dx=2. Normal (0, -2) -> (0, -1).
        # (p - v) dot n. (0.5, 0.5) - (0,0) = (0.5, 0.5). dot (0,-1) = -0.5. Correct.
        # Edge 2: (2,0)->(0,2). dy=2, dx=-2. Normal (2, 2) -> (1/r2, 1/r2).
        # (0.5, 0.5) - (2,0) = (-1.5, 0.5). dot (0.7, 0.7) = -1.0 / 1.414 = -0.707. Correct.
        # Edge 3: (0,2)->(0,0). dy=-2, dx=0. Normal (-2, 0) -> (-1, 0).
        # (0.5, 0.5) - (0,2) = (0.5, -1.5). dot (-1, 0) = -0.5. Correct.
        # Max is -0.5.
        @test d ≈ -0.5f0 atol=1e-5

        # 2. Outside (Edge 1 Region)
        o1 = SVector(1.0f0, -1.0f0)
        d1 = Common.sdf(poly, o1, 0.0f0)
        @test d1 ≈ 1.0f0

        # 3. Outside (Vertex Region p1)
        o2 = SVector(-1.0f0, -1.0f0)
        d2 = Common.sdf(poly, o2, 0.0f0)
        @test d2 ≈ sqrt(2.0f0)
    end

    @testset "Rotating" begin
        # Rectangle [-2, 2] x [-1, 1]
        rect = Shapes.Box(4.0f0, 2.0f0)

        # Rotate 90 degrees/sec
        rot_rect = Shapes.Rotating(rect, Float32(pi/2))

        # t=0. Unrotated. Point at (3, 0).
        # Box width/2 = 2. Dist = 1.
        p0 = SVector(3.0f0, 0.0f0)
        c, d, n = Common.detect_collision(rot_rect, p0, 0.0f0)
        @test c
        @test d ≈ 1.0f0
        @test n[1] ≈ 1.0f0

        # t=1. Rotated 90 deg.
        # Box is now vertical: [-1, 1] x [-2, 2].
        # Point at (3, 0) is now far from side (x=1). Dist = 2.
        c, d, n = Common.detect_collision(rot_rect, p0, 1.0f0)
        @test c
        @test d ≈ 2.0f0
        @test n[1] ≈ 1.0f0 # Normal still points along X?
        # At (3,0), closest point on box is (1,0). Normal (1,0).

        # Point at (0, 3).
        # Closest point (0, 2). Dist = 1. Normal (0, 1).
        p_top = SVector(0.0f0, 3.0f0)
        c, d, n = Common.detect_collision(rot_rect, p_top, 1.0f0)
        @test c
        @test d ≈ 1.0f0
        @test abs(n[1]) < 1e-5
        @test n[2] ≈ 1.0f0
    end

    @testset "VortexField" begin
        v = Fields.VortexField(SVector(0.0f0, 0.0f0), 10.0f0)
        p = SVector(2.0f0, 0.0f0)

        # Vortex logic:
        # diff = (2,0). dist=2.
        # scalar = strength / denom^3 = 10 / 8 = 1.25
        # tangent = (-y, x) = (0, 2)
        # F = tangent * scalar = (0, 2.5)

        f = v(p, SVector(0f0,0f0), 1.0f0, 0.0f0)
        @test f ≈ SVector(0.0f0, 2.5f0)
    end
end
