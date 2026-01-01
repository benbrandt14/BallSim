using Test
using StaticArrays
using LinearAlgebra
using Random
using BallSim
using BallSim.Common
using BallSim.Shapes
using BallSim.Physics

include("fixtures.jl")
using .TestFixtures

@testset "Module: Benchmarks" begin
    TestFixtures.print_header("Comparative Benchmark: The Pressure Cooker")

    scenario = TestFixtures.Scenario(
        "Pressure Cooker",
        0.5,
        () -> begin
            Random.seed!(42)
            sys = Common.BallSystem(1000, 2, Float32)
            for i in 1:1000
                sys.data.active[i] = true
                sys.data.pos[i] = SVector((rand(Float32)-0.5f0)*1.8f0, (rand(Float32)-0.5f0)*1.8f0)
                sys.data.vel[i] = SVector(randn(Float32), randn(Float32)) * 25.0f0
            end
            sys
        end,
        Shapes.Box(2.0f0, 2.0f0),
        Common.Gravity2D
    )

    solvers = Dict(
        "Discrete (Low)"  => Physics.DiscreteSolver(0.005f0, 2, 1.0f0),
        "Discrete (High)" => Physics.DiscreteSolver(0.005f0, 10, 1.0f0),
        "CCD (Standard)"  => Physics.CCDSolver(0.005f0, 1.0f0, 8)
    )

    results = TestFixtures.compare_solvers(scenario, solvers)
    ccd = filter(r -> r.name == "CCD (Standard)", results)[1]
    @test ccd.passed
end
