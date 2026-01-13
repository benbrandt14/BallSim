using BallSim
using StaticArrays
using Test
using LinearAlgebra

# Ellipsoid Collision Test
@testset "Ellipsoid Collision Optimization" begin
    # 2:1 Ellipsoid
    e = Shapes.Ellipsoid(2.0f0, 1.0f0)

    # 1. Point deep inside (no collision)
    p_in = SVector(0.5f0, 0.0f0)
    c, d, n = Common.detect_collision(e, p_in, 0.0f0)
    @test c == false
    @test d == 0.0f0

    # 2. Point outside (collision)
    # At (3,0). SDF approx distance?
    # k = 3/2 = 1.5.
    # gx = 3 / (1.5 * 4) = 3/6 = 0.5. gy = 0.
    # grad_len = 0.5.
    # dist = (1.5 - 1) / 0.5 = 0.5 / 0.5 = 1.0.
    # Real distance: 3 - 2 = 1.0. Correct.
    p_out = SVector(3.0f0, 0.0f0)
    c, d, n = Common.detect_collision(e, p_out, 0.0f0)
    @test c == true
    @test isapprox(d, 1.0f0, atol=1e-5)
    @test isapprox(n[1], 1.0f0, atol=1e-5)
    @test isapprox(n[2], 0.0f0, atol=1e-5)

    # 3. Point outside on Y axis
    # At (0, 2).
    # k = 2/1 = 2.
    # gx = 0. gy = 2 / (2 * 1) = 1.
    # grad_len = 1.
    # dist = (2 - 1) / 1 = 1.
    # Real distance: 2 - 1 = 1. Correct.
    p_out_y = SVector(0.0f0, 2.0f0)
    c, d, n = Common.detect_collision(e, p_out_y, 0.0f0)
    @test c == true
    @test isapprox(d, 1.0f0, atol=1e-5)
    @test isapprox(n[1], 0.0f0, atol=1e-5)
    @test isapprox(n[2], 1.0f0, atol=1e-5)

    # 4. Point at 45 degrees (approx)
    # p = (2, 2)
    p_diag = SVector(2.0f0, 2.0f0)
    c, d, n = Common.detect_collision(e, p_diag, 0.0f0)
    @test c == true
    @test d > 0.0f0
    @test n[1] > 0.0f0
    @test n[2] > 0.0f0
    # Check normalized
    @test isapprox(norm(n), 1.0f0, atol=1e-5)

    # Verify optimization matches fallback logic (semantically)
    # We can't call fallback directly easily, but we know the math.
end
