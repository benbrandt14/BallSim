using Test
using BallSim.Common
using BallSim.Scenarios
using StaticArrays
using LinearAlgebra

# Enforce the Factory Pattern. A Scenario is just data; setup_system does the work.

# Mock Implementation for Testing
struct MockScenario <: Common.AbstractScenario{2}
    N::Int
end

@testset "Unit: Scenario Factory" begin
    @testset "Spiral 2D" begin
        # 1. Define the recipe
        N_particles = 1000
        scen = Scenarios.SpiralScenario(N = N_particles)

        # 2. Verify Protocol Compliance
        @test scen isa Common.AbstractScenario{2}

        # 3. Verify Factory Output
        sys = Common.setup_system(scen)

        @test length(sys.data.pos) == N_particles
        @test count(sys.data.active) == N_particles # Should be fully active
        @test sys isa Common.BallSystem{2}

        # 4. Verify Initial Distribution (Smoke Test)
        # Ensure not all points are at 0,0
        @test sum(norm.(sys.data.pos)) > 0.0
    end

    @testset "Spiral 3D" begin
        N_particles = 500
        scen = Scenarios.SpiralScenario3D(N = N_particles)

        @test scen isa Common.AbstractScenario{3}

        sys = Common.setup_system(scen)

        @test length(sys.data.pos) == N_particles
        @test count(sys.data.active) == N_particles
        @test sys isa Common.BallSystem{3}

        # Verify Z distribution (SpiralScenario3D sets z from -1 to 1)
        zs = [sys.data.pos[i][3] for i in 1:length(sys.data.pos) if sys.data.active[i]]
        @test minimum(zs) ≈ -1.0f0 atol=0.1
        @test maximum(zs) ≈ 1.0f0 atol=0.1
    end
end
