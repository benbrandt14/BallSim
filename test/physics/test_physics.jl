using Test
using StaticArrays
using LinearAlgebra
using BallSim.Common
using BallSim.Shapes
using BallSim.Physics

@testset "Physics: Invariants" begin
    @testset "Energy Conservation (Vacuum)" begin
        # 1. Setup V2 System
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(0f0, 0f0)
        sys.data.vel[1] = SVector(5.0f0, 2.0f0)
        
        # 2. Solver Setup
        solver = Physics.CCDSolver(0.01f0, 1.0f0, 8)
        boundary = Shapes.Box(10.0f0, 10.0f0)
        gravity = (p,v,m,t) -> SVector(0f0, 0f0) # Vacuum
        
        # 3. Measure Initial Energy
        E_init = 0.5f0 * norm(sys.data.vel[1])^2
        
        # 4. Run 100 steps
        for _ in 1:100 
            Physics.step!(sys, solver, boundary, gravity)
        end
        
        # 5. Measure Final Energy
        E_final = 0.5f0 * norm(sys.data.vel[1])^2
        
        # Assert drift is negligible
        @test isapprox(E_init, E_final, atol=1e-5)
    end

    @testset "Tunneling Prevention" begin
        # High speed particle moving towards wall
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(0.9f0, 0f0)
        sys.data.vel[1] = SVector(100.0f0, 0f0) # Very fast
        
        solver = Physics.CCDSolver(0.01f0, 1.0f0, 8)
        boundary = Shapes.Circle(1.0f0)
        gravity = (p,v,m,t) -> SVector(0f0, 0f0)
        
        # Step
        Physics.step!(sys, solver, boundary, gravity)
        
        # Assert it is still inside (distance <= 0)
        dist = Common.sdf(boundary, sys.data.pos[1], 0f0)
        @test dist <= 1e-4
        
        # Assert it bounced (velocity flipped)
        @test sys.data.vel[1][1] < 0
    end
end