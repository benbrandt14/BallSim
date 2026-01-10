using Test
using BallSim.Common
using BallSim.Shapes
using StaticArrays
using LinearAlgebra

"""
    finite_difference_gradient(f, p, ε=1f-4)

Computes the numerical gradient of scalar function `f` at point `p` using central differences.
"""
function finite_difference_gradient(f, p::SVector{2}, ε=1f-4)
    dx = SVector(ε, 0f0)
    dy = SVector(0f0, ε)
    df_dx = (f(p + dx) - f(p - dx)) / (2 * ε)
    df_dy = (f(p + dy) - f(p - dy)) / (2 * ε)
    return SVector(df_dx, df_dy)
end

function finite_difference_gradient(f, p::SVector{3}, ε=1f-4)
    dx = SVector(ε, 0f0, 0f0)
    dy = SVector(0f0, ε, 0f0)
    dz = SVector(0f0, 0f0, ε)
    df_dx = (f(p + dx) - f(p - dx)) / (2 * ε)
    df_dy = (f(p + dy) - f(p - dy)) / (2 * ε)
    df_dz = (f(p + dz) - f(p - dz)) / (2 * ε)
    return SVector(df_dx, df_dy, df_dz)
end

@testset "Parametric Shape Tests" begin

    # 1. Define Test Candidates
    # Define (Name, Shape, PointOutside, PointInside)
    # Using specific points for Ellipsoid to ensure SDF gradient consistency (close to surface)
    shapes_2d = [
        ("Circle", Shapes.Circle(5.0f0), SVector(10.0f0, 10.0f0), SVector(0.1f0, 0.1f0)),
        ("Box", Shapes.Box(4.0f0, 6.0f0), SVector(10.0f0, 10.0f0), SVector(0.1f0, 0.1f0)),
        # Ellipsoid: Use points closer to surface to ensure approximate SDF gradient matches analytical normal
        # Surface at (5,0) and (0,3).
        # Check near (5,0)
        ("Ellipsoid", Shapes.Ellipsoid(5.0f0, 3.0f0), SVector(5.1f0, 0.0f0), SVector(4.9f0, 0.0f0)),
        # Inverted Circle:
        # Inner Circle has r=5.
        # Inside inner (dist < 5) -> Inverted SDF is POSITIVE (Collision/Obstacle).
        # Outside inner (dist > 5) -> Inverted SDF is NEGATIVE (Valid Space).
        ("InvertedCircle", Shapes.Inverted(Shapes.Circle(5.0f0)), SVector(0.1f0, 0.1f0), SVector(10.0f0, 10.0f0))
    ]

    shapes_3d = [
        ("Circle3D", Shapes.Circle3D(5.0f0), SVector(10.0f0, 10.0f0, 10.0f0), SVector(0.1f0, 0.1f0, 0.1f0)),
        ("Box3D", Shapes.Box3D(4.0f0, 6.0f0, 2.0f0), SVector(10.0f0, 10.0f0, 10.0f0), SVector(0.1f0, 0.1f0, 0.1f0)),
        ("InvertedCircle3D", Shapes.Inverted(Shapes.Circle3D(5.0f0)), SVector(0.1f0, 0.1f0, 0.1f0), SVector(10.0f0, 10.0f0, 10.0f0))
    ]

    t = 0.0f0

    @testset "2D Shapes Consistency" begin
        for (name, shape, p_out, p_in) in shapes_2d
            @testset "$name" begin
                # Verify Signs
                @test Common.sdf(shape, p_out, t) > 0
                @test Common.sdf(shape, p_in, t) < 0

                # Verify Normal vs Gradient Consistency (Outside)
                n_ana = Common.normal(shape, p_out, t)
                grad_num = finite_difference_gradient(x -> Common.sdf(shape, x, t), p_out)

                @test isapprox(n_ana, normalize(grad_num), atol=1e-2)

                # Verify Normal vs Gradient Consistency (Inside)
                n_ana_in = Common.normal(shape, p_in, t)
                grad_num_in = finite_difference_gradient(x -> Common.sdf(shape, x, t), p_in)

                @test isapprox(n_ana_in, normalize(grad_num_in), atol=1e-2)
            end
        end
    end

    @testset "3D Shapes Consistency" begin
        for (name, shape, p_out, p_in) in shapes_3d
            @testset "$name" begin
                @test Common.sdf(shape, p_out, t) > 0
                @test Common.sdf(shape, p_in, t) < 0

                # Gradient Check
                n_ana = Common.normal(shape, p_out, t)
                grad_num = finite_difference_gradient(x -> Common.sdf(shape, x, t), p_out)

                @test isapprox(n_ana, normalize(grad_num), atol=1e-2)
            end
        end
    end
end
