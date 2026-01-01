using Test
using BallSim.Common
using BallSim.Scenarios
using StaticArrays

# Enforce the Factory Pattern. A Scenario is just data; setup_system does the work.

# Mock Implementation for Testing
struct MockScenario <: Common.AbstractScenario{2}
    N::Int
end

@testset "Unit: Scenario Factory" begin
    # 1. Define the recipe
    N_particles = 1000
    scen = Scenarios.SpiralScenario(N=N_particles)

    # 2. Verify Protocol Compliance
    @test scen isa Common.AbstractScenario{2}
    
    # 3. Verify Factory Output
    sys = Common.setup_system(scen)
    
    @test length(sys.data.pos) == N_particles
    @test count(sys.data.active) == N_particles # Should be fully active
    
    # 4. Verify Initial Distribution (Smoke Test)
    # Ensure not all points are at 0,0
    @test sum(norm.(sys.data.pos)) > 0.0
end