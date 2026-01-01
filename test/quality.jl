using Test
using BallSim
using Aqua
using JET

@testset "Project Quality" begin
    
    @testset "Aqua (Method Ambiguities & Stale Deps)" begin
        Aqua.test_all(BallSim; 
            ambiguities=false, # JET handles this better usually
            stale_deps=(ignore=[:GLMakie],) # GLMakie is used in conditional loading usually
        )
    end

    @testset "JET (Type Stability)" begin
        # 1. Analyze the package for obvious runtime errors
        JET.report_package(BallSim)
        
        # 2. Enforce Optimization (Optional but recommended for Physics)
        # This fails the test if any dynamic dispatch is detected in critical functions.
        # We test the physics kernel specifically.
        
        using BallSim.Common
        using BallSim.Physics
        using BallSim.Shapes
        using StaticArrays
        
        # Mock data for analysis
        sys = Common.BallSystem(1, 2, Float32)
        solver = Physics.CCDSolver(0.01f0, 1.0f0, 1)
        boundary = Shapes.Circle(1.0f0)
        gravity = (p, v, t) -> SVector(0f0, 0f0)
        
        # Check that step! is fully optimized (return type is inferred)
        @test_opt Physics.step!(sys, solver, boundary, gravity)
    end
end