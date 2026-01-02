using Test
using BallSim
using Aqua
using JET

@testset "Project Quality" begin
    
    @testset "Aqua (Method Ambiguities & Stale Deps)" begin
        Aqua.test_all(BallSim; 
            ambiguities=false,
            stale_deps=(ignore=[:GLMakie],),
            persistent_tasks=false,
        )
    end

    @testset "JET (Type Stability)" begin
        # 1. Analyze package (General)
        JET.report_package(BallSim)
        
        # 2. Physics Optimization Check
        using BallSim.Common
        using BallSim.Physics
        using BallSim.Shapes
        using StaticArrays
        
        sys = Common.BallSystem(1, 2, Float32)
        solver = Physics.CCDSolver(0.01f0, 1.0f0, 1)
        boundary = Shapes.Circle(1.0f0)
        gravity = (p, v, t) -> SVector(0f0, 0f0)
        
        # Ignore Base/Threads noise
        @test_opt target_modules=(BallSim,) Physics.step!(sys, solver, boundary, gravity)
    end
end