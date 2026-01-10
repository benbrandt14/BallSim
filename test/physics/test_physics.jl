using Test
using StaticArrays
using LinearAlgebra
using BallSim.Common
using BallSim.Shapes
using BallSim.Physics

@testset "Physics: Invariants" begin
    @testset "Energy Conservation (Vacuum) - 2D" begin
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

    @testset "Energy Conservation (Vacuum) - 3D" begin
        # 1. Setup V3 System
        sys = Common.BallSystem(1, 3, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(0f0, 0f0, 0f0)
        sys.data.vel[1] = SVector(2.0f0, 3.0f0, 4.0f0)

        # 2. Solver Setup
        solver = Physics.CCDSolver(0.01f0, 1.0f0, 8)
        # Use a large Sphere as boundary so we don't hit it
        boundary = Shapes.Circle3D(100.0f0)
        gravity = (p,v,m,t) -> SVector(0f0, 0f0, 0f0) # Vacuum

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

    @testset "Gravity Acceleration" begin
        # 1. Setup V2 System
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(0f0, 0f0)
        sys.data.vel[1] = SVector(0f0, 0f0)
        sys.data.mass[1] = 2.0f0

        # 2. Solver Setup
        # Use small dt and 1 substep to check exact acceleration integration
        dt = 0.1f0
        solver = Physics.CCDSolver(dt, 1.0f0, 1)
        boundary = Shapes.Box(100.0f0, 100.0f0)

        # Force F = (0, -10)
        # Acceleration a = F/m = (0, -5)
        gravity = (p,v,m,t) -> SVector(0f0, -10.0f0)

        # 3. Step
        Physics.step!(sys, solver, boundary, gravity)

        # 4. Check Velocity
        # v_new = v + a * dt = (0, 0) + (0, -5) * 0.1 = (0, -0.5)
        @test isapprox(sys.data.vel[1], SVector(0f0, -0.5f0), atol=1e-5)

        # 5. Check Position
        # p_new = p + v_new * dt = (0, 0) + (0, -0.5) * 0.1 = (0, -0.05)
        # Note: step! does v_new = v + a*dt, then p_new = p + v_new * dt (Semi-Implicit Euler)
        @test isapprox(sys.data.pos[1], SVector(0f0, -0.05f0), atol=1e-5)
    end

    @testset "Variable Mass Dynamics" begin
        # Check that heavy objects accelerate slower for the same FORCE
        # (Note: Gravity fields usually return F = m*g, so acceleration is constant g.
        #  We need a fixed force field to see mass difference.)

        sys = Common.BallSystem(2, 2, Float32)
        sys.data.active[1] = true
        sys.data.active[2] = true

        sys.data.mass[1] = 1.0f0
        sys.data.mass[2] = 2.0f0

        sys.data.vel[1] = SVector(0f0, 0f0)
        sys.data.vel[2] = SVector(0f0, 0f0)

        dt = 1.0f0
        solver = Physics.CCDSolver(dt, 1.0f0, 1)
        boundary = Shapes.Box(100f0, 100f0)

        # Constant Force Field F = (10, 0) regardless of mass
        const_force = (p,v,m,t) -> SVector(10.0f0, 0.0f0)

        Physics.step!(sys, solver, boundary, const_force)

        # a1 = F/m1 = 10/1 = 10. v1 = 10*1 = 10
        # a2 = F/m2 = 10/2 = 5.  v2 = 5*1 = 5

        @test isapprox(sys.data.vel[1][1], 10.0f0, atol=1e-5)
        @test isapprox(sys.data.vel[2][1], 5.0f0, atol=1e-5)
    end

    @testset "Tunneling Prevention (Thick Wall)" begin
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

    @testset "Tunneling Prevention (Thin Box)" begin
        # 1. Setup: Particle moving fast towards a thin box boundary
        # Box is 10 wide, 10 high. Right wall is at x=5.
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(4.9f0, 0f0)
        sys.data.vel[1] = SVector(100.0f0, 0f0)

        # 2. Solver: use substeps to catch it
        solver = Physics.CCDSolver(0.01f0, 1.0f0, 20) # 20 substeps
        boundary = Shapes.Box(10.0f0, 10.0f0)
        gravity = (p,v,m,t) -> SVector(0f0, 0f0)

        Physics.step!(sys, solver, boundary, gravity)

        # 3. Verify it bounced
        @test sys.data.pos[1][1] <= 5.0f0
        @test sys.data.vel[1][1] < 0
    end

    @testset "Collision Counting - 2D" begin
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(0.99f0, 0f0)
        sys.data.vel[1] = SVector(1.0f0, 0f0) # Moving towards right wall at x=1

        dt = 0.1f0
        solver = Physics.CCDSolver(dt, 1.0f0, 1)
        boundary = Shapes.Circle(1.0f0)
        gravity = (p,v,m,t) -> SVector(0f0, 0f0)

        @test sys.data.collisions[1] == 0

        Physics.step!(sys, solver, boundary, gravity)

        @test sys.data.collisions[1] == 1
        @test sys.data.vel[1][1] < 0
    end

    @testset "Collision Counting - 3D" begin
        sys = Common.BallSystem(1, 3, Float32)
        sys.data.active[1] = true
        # Box3D(2,2,2) -> bounds at +/- 1
        sys.data.pos[1] = SVector(0.99f0, 0.0f0, 0.0f0)
        sys.data.vel[1] = SVector(1.0f0, 0.0f0, 0.0f0)

        dt = 0.1f0
        solver = Physics.CCDSolver(dt, 1.0f0, 1)
        boundary = Shapes.Box3D(2.0f0, 2.0f0, 2.0f0)
        gravity = (p,v,m,t) -> SVector(0f0, 0f0, 0f0)

        @test sys.data.collisions[1] == 0

        Physics.step!(sys, solver, boundary, gravity)

        @test sys.data.collisions[1] == 1
        @test sys.data.vel[1][1] < 0
    end

    @testset "Inverted Circle (Obstacle)" begin
        # Particle outside the obstacle (valid space for Inverted is Outside the inner circle)
        # Test: Particle moving TOWARDS the circle from outside.
        # Circle radius 1. Start closer to ensure penetration in one step.
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(1.05f0, 0f0)
        sys.data.vel[1] = SVector(-1.0f0, 0f0)

        solver = Physics.CCDSolver(0.1f0, 1.0f0, 5)
        # Inverted Circle: The circle itself is the solid object.
        boundary = Shapes.Inverted(Shapes.Circle(1.0f0))
        gravity = (p,v,m,t) -> SVector(0f0, 0f0)

        Physics.step!(sys, solver, boundary, gravity)

        # Should bounce off the surface at r=1
        @test sys.data.pos[1][1] >= 1.0f0 # Stay outside
        @test sys.data.vel[1][1] > 0 # Reversed direction
    end

    @testset "Ellipsoid Reflection" begin
        # Ellipsoid (5, 3).
        # Particle at (4.9, 0) moving right -> hits tip at (5,0)
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(4.9f0, 0f0)
        sys.data.vel[1] = SVector(5.0f0, 0f0)

        # Increase dt to ensure it crosses the boundary (4.9 + 5*0.1 = 5.4 > 5.0)
        solver = Physics.CCDSolver(0.1f0, 1.0f0, 10)
        boundary = Shapes.Ellipsoid(5.0f0, 3.0f0)
        gravity = (p,v,m,t) -> SVector(0f0, 0f0)

        Physics.step!(sys, solver, boundary, gravity)

        @test sys.data.pos[1][1] <= 5.0f0 # Inside
        @test sys.data.vel[1][1] < 0 # Bounced
    end

    @testset "Restitution (Energy Loss)" begin
        # 1. Setup V2 System
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(4.9f0, 0f0) # Near right wall
        sys.data.vel[1] = SVector(10.0f0, 0f0) # Moving right

        # 2. Solver Setup: Restitution 0.5
        restitution = 0.5f0
        solver = Physics.CCDSolver(0.01f0, restitution, 10)
        boundary = Shapes.Box(10.0f0, 10.0f0) # Wall at x=5
        gravity = (p,v,m,t) -> SVector(0f0, 0f0)

        Physics.step!(sys, solver, boundary, gravity)

        # 3. Check Velocity magnitude
        # Should be flipped and halved
        @test sys.data.vel[1][1] < 0
        @test isapprox(abs(sys.data.vel[1][1]), 10.0f0 * restitution, atol=0.1)
    end
end
