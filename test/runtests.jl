using Test
using BallSim

@testset "BallSim TDD Suite" begin
    # 1. Diagnostics (Fail Fast)
    include("quality.jl")

    # 2. Unit Specs
    include("unit/test_common.jl")
    include("unit/test_common_edge.jl")
    include("unit/test_common_soa.jl")
    include("unit/test_scenarios.jl")
    include("unit/test_shapes_extended.jl")
    include("shapes/test_inverted.jl") # Added
    include("shapes/test_shapes_3d.jl")
    include("shapes/test_shapes_parametric.jl")
    include("vis/test_projection.jl")
    include("unit/test_fields.jl")
    include("unit/test_config.jl")
    include("unit/test_io.jl")
    include("unit/test_demo_features.jl")

    # 3. Physics & Regression
    include("physics/test_physics.jl")
    include("physics/test_physics_step.jl") # Added
    include("physics/test_collisions_parametric.jl")
    include("regression/test_golden.jl")
end
