using Test
using Aqua
using BallSim

@testset "BallSim TDD Suite" begin
    # 0. Quality Assurance
    @testset "Code Quality" begin
        Aqua.test_all(BallSim; ambiguities=false)
    end

    # 1. Unit Specs (The Refactor Targets)
    include("unit/test_common.jl")
    include("unit/test_scenarios.jl")
    include("unit/test_io.jl")

    # 2. Physics & Regression (Existing)
    # include("physics/test_physics.jl") 
    # include("regression/test_regression.jl")
end