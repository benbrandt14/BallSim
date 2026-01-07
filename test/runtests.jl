using Test
using BallSim

@testset "BallSim TDD Suite" begin
    # 1. Diagnostics (Fail Fast)
    include("quality.jl")

    # 2. Unit Specs
    include("unit/test_common.jl")
    include("unit/test_scenarios.jl")
    include("unit/test_shapes_extended.jl")
    include("test_shapes3d.jl")
    include("unit/test_fields.jl")
    include("unit/test_config.jl")
    include("unit/test_io.jl")

    # 3. Physics & Regression
    include("physics/test_physics.jl")
end