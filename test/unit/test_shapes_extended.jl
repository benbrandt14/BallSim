using Test
using BallSim.Common
using BallSim.Shapes
using StaticArrays
using LinearAlgebra

@testset "Extended Shapes" begin
    
    @testset "Inverted Wrapper" begin
        # 1. Define a standard circle
        circle = Shapes.Circle(10.0f0)
        # 2. Invert it (The "Void")
        void = Shapes.Inverted(circle)
        
        p_inside = SVector(5.0f0, 0.0f0)
        p_outside = SVector(15.0f0, 0.0f0)
        
        # Test SDF Logic
        # Normal Circle: Inside is negative
        @test Common.sdf(circle, p_inside, 0f0) < 0
        # Inverted Circle: Inside the void is POSITIVE (valid space), 
        # but wait - usually "SDF < 0" means "Inside the solid".
        # Let's define the standard: 
        # SDF > 0 means "Outside/Safe". SDF < 0 means "Collision/Penetration".
        # For a Circle, p_inside is safe? No, p_inside is colliding? 
        # Standard: SDF < 0 is "Inside the object". 
        # If we are in a Void, "Inside the Circle" is the safe zone.
        # So Inverted SDF should be NEGATED Circle SDF.
        
        # Check specific values
        # Circle at 5.0 (R=10): Dist = 5 - 10 = -5 (Inside)
        # Void at 5.0: Should be +5 (Safe)
        @test Common.sdf(void, p_inside, 0f0) == 5.0f0
        
        # Circle at 15.0 (R=10): Dist = 15 - 10 = +5 (Outside)
        # Void at 15.0: Should be -5 (Collision with wall)
        @test Common.sdf(void, p_outside, 0f0) == -5.0f0
        
        # Test Normal Logic
        # Circle normal at 15.0 points OUT (1, 0)
        n_circ = Common.normal(circle, p_outside, 0f0)
        @test n_circ ≈ SVector(1.0f0, 0.0f0)
        
        # Void normal at 15.0 should point IN (-1, 0) (pushing particle back)
        n_void = Common.normal(void, p_outside, 0f0)
        @test n_void ≈ SVector(-1.0f0, 0.0f0)
    end

    @testset "Ellipsoid" begin
        # Ellipsoid with radii X=10, Y=5
        ell = Shapes.Ellipsoid(10.0f0, 5.0f0)
        
        # Test Point on Surface (X-axis)
        p_surf_x = SVector(10.0f0, 0.0f0)
        @test isapprox(Common.sdf(ell, p_surf_x, 0f0), 0.0f0, atol=1e-4)
        
        # Test Point on Surface (Y-axis)
        p_surf_y = SVector(0.0f0, 5.0f0)
        @test isapprox(Common.sdf(ell, p_surf_y, 0f0), 0.0f0, atol=1e-4)
        
        # Test Point Outside (X-axis)
        p_out = SVector(12.0f0, 0.0f0)
        @test isapprox(Common.sdf(ell, p_out, 0f0), 2.0f0, atol=1e-4)
    end
end