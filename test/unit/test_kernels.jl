using Test
using BallSim
using StaticArrays
using KernelAbstractions

@testset "Physics Kernels (CPU)" begin
    # Create a system with 2 particles
    sys = Common.BallSystem(2, 2)

    # Particle 1: Moving Right, affected by gravity
    sys.data.pos[1] = SVector(0.0f0, 0.0f0)
    sys.data.vel[1] = SVector(1.0f0, 0.0f0)
    sys.data.active[1] = true
    sys.data.mass[1] = 1.0f0

    # Particle 2: Stationary, heavier
    sys.data.pos[2] = SVector(5.0f0, 5.0f0)
    sys.data.vel[2] = SVector(0.0f0, 0.0f0)
    sys.data.active[2] = true
    sys.data.mass[2] = 2.0f0

    solver = Physics.CCDSolver(0.1f0, 1.0f0, 1) # dt=0.1
    boundary = Shapes.Circle(100.0f0)
    gravity = (p, v, m, t) -> SVector(0.0f0, -9.8f0) * m # F = ma

    # Run one step
    Physics.step!(sys, solver, boundary, gravity)

    # Analytical Check for Particle 1
    # F = (0, -9.8) * 1 = (0, -9.8)
    # a = F/m = (0, -9.8)
    # v_new = v + a*dt = (1, 0) + (0, -0.98) = (1.0, -0.98)
    # p_new = p + v_new*dt = (0, 0) + (0.1, -0.098) = (0.1, -0.098)

    p1 = sys.data.pos[1]
    v1 = sys.data.vel[1]

    @test isapprox(p1[1], 0.1f0; atol=1e-5)
    @test isapprox(p1[2], -0.098f0; atol=1e-5)
    @test isapprox(v1[1], 1.0f0; atol=1e-5)
    @test isapprox(v1[2], -0.98f0; atol=1e-5)

    @test sys.t ≈ 0.1f0
    @test sys.iter == 1

    println("✅ Physics Kernels CPU Test Passed")
end
