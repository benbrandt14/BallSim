using Test
using BallSim
using BallSim.Common
using BallSim.Physics
using BallSim.Shapes
using StaticArrays
using LinearAlgebra

@testset "Physics Step Integration" begin
    # Helper to create system
    function create_sys(n=1, d=2)
        sys = Common.BallSystem(n, d, Float32)
        sys.data.active .= true
        return sys
    end

    @testset "Force Integration (F=ma)" begin
        # Verify that a constant force integrates correctly to position and velocity
        # x(t) = x0 + v0*t + 0.5*a*t^2
        # v(t) = v0 + a*t

        sys = create_sys(1)
        sys.data.pos[1] = SVector(0.0f0, 0.0f0)
        sys.data.vel[1] = SVector(0.0f0, 0.0f0)
        sys.data.mass[1] = 2.0f0 # Mass = 2

        # Force = (10, 0). Accel = 5.
        force_func = (p, v, m, t) -> SVector(10.0f0, 0.0f0)

        dt = 0.1f0
        solver = Physics.CCDSolver(dt, 1.0f0, 1) # 1 substep
        boundary = Shapes.Box(100.0f0, 100.0f0) # Far away

        Physics.step!(sys, solver, boundary, force_func)

        # Expected v = 0 + 5 * 0.1 = 0.5
        @test sys.data.vel[1][1] ≈ 0.5f0 atol=1e-5
        # Expected p (Semi-Implicit Euler in Physics.jl):
        # v_new = v_old + a*dt
        # p_new = p_old + v_new*dt
        # p = 0 + 0.5 * 0.1 = 0.05
        @test sys.data.pos[1][1] ≈ 0.05f0 atol=1e-5
    end

    @testset "Drag Integration" begin
        # Verify drag slows down particle
        sys = create_sys(1)
        v0 = 10.0f0
        sys.data.pos[1] = SVector(0.0f0, 0.0f0)
        sys.data.vel[1] = SVector(v0, 0.0f0)
        sys.data.mass[1] = 1.0f0

        # F = -k * v. k=1.
        drag_func = (p, v, m, t) -> -1.0f0 * v

        dt = 0.1f0
        solver = Physics.CCDSolver(dt, 1.0f0, 10) # 10 substeps for stability
        boundary = Shapes.Box(100.0f0, 100.0f0)

        Physics.step!(sys, solver, boundary, drag_func)

        # Velocity should decrease
        @test sys.data.vel[1][1] < v0
        @test sys.data.vel[1][1] > 0.0f0 # But not reverse
    end

    @testset "Substep Stability" begin
        # Verify that increasing substeps yields same result for constant force
        # (It should, for constant acceleration, but for position integration:
        #  One step: p = p + (v+a*dt)*dt = p + v*dt + a*dt^2
        #  Two steps (dt/2):
        #    v1 = v + a*dt/2
        #    p1 = p + v1*dt/2 = p + v*dt/2 + a*dt^2/4
        #    v2 = v1 + a*dt/2 = v + a*dt
        #    p2 = p1 + v2*dt/2 = p + v*dt/2 + a*dt^2/4 + (v+a*dt)*dt/2
        #       = p + v*dt + a*dt^2/4 + a*dt^2/2
        #       = p + v*dt + 0.75 * a*dt^2
        #  Wait, Semi-Implicit Euler error depends on dt.
        #  So results WILL differ. This test documents that behavior.)

        sys1 = create_sys(1)
        sys1.data.vel[1] = SVector(0.0f0, 0.0f0)
        sys1.data.mass[1] = 1.0f0

        sys2 = create_sys(1)
        sys2.data.vel[1] = SVector(0.0f0, 0.0f0)
        sys2.data.mass[1] = 1.0f0

        force_func = (p, v, m, t) -> SVector(10.0f0, 0.0f0)
        boundary = Shapes.Box(100.0f0, 100.0f0)
        dt = 1.0f0

        # Solver 1: 1 substep
        solver1 = Physics.CCDSolver(dt, 1.0f0, 1)
        Physics.step!(sys1, solver1, boundary, force_func)

        # Solver 2: 100 substeps (converges to exact integral)
        solver2 = Physics.CCDSolver(dt, 1.0f0, 100)
        Physics.step!(sys2, solver2, boundary, force_func)

        # Exact integration: x = 0.5 * a * t^2 = 0.5 * 10 * 1 = 5.0
        # 1 Substep (Semi-Implicit): x = a*dt^2 = 10.0
        # 100 Substeps: Should be closer to 5.0

        @test sys1.data.pos[1][1] ≈ 10.0f0 atol=1e-5
        @test isapprox(sys2.data.pos[1][1], 5.0f0, atol=0.1)
    end
end
