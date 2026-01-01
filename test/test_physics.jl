using Test
using StaticArrays
using LinearAlgebra
using BallSim
using BallSim.Common
using BallSim.Shapes
using BallSim.Physics

include("fixtures.jl")
using .TestFixtures

@testset "Module: Physics" begin
    @testset "Integration Accuracy (CCD)" begin
        TestFixtures.print_header("Physics: Single Particle Energy Conservation")
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(0f0, 0f0)
        sys.data.vel[1] = SVector(5.0f0, 2.0f0)

        solver = Physics.CCDSolver(0.005f0, 1.0f0, 8)
        boundary = Shapes.Box(10.0f0, 10.0f0)
        gravity = (p,v,t) -> SVector(0f0, 0f0)

        E_init = 0.5f0 * norm(sys.data.vel[1])^2
        for _ in 1:500 Physics.step!(sys, solver, boundary, gravity) end

        E_final = 0.5f0 * norm(sys.data.vel[1])^2
        drift = abs(E_final - E_init) / E_init

        println("Initial E: $E_init, Final E: $E_final, Drift: $(drift*100)%")
        @test drift < 1e-4
    end

    @testset "Tunneling Prevention" begin
        TestFixtures.print_header("Physics: Tunneling Stress Test")
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(0.9f0, 0f0)
        sys.data.vel[1] = SVector(100.0f0, 0f0)

        solver = Physics.CCDSolver(0.01f0, 1.0f0, 10)
        boundary = Shapes.Circle(1.0f0)

        Physics.step!(sys, solver, boundary, (p,v,t)->SVector(0f0,0f0))
        dist = Common.sdf(boundary, sys.data.pos[1], 0f0)

        if dist > 0 println("[FAIL] Particle escaped to distance $dist")
        else println("[PASS] Particle contained at distance $dist") end

        @test dist <= 1e-4
        @test sys.data.vel[1][1] < 0
    end
end
