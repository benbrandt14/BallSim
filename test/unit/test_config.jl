using Test
using BallSim
using BallSim.Config
using BallSim.Shapes
using BallSim.Scenarios
using BallSim.Fields
using BallSim.Physics
using BallSim.Common
using YAML

@testset "Config Validation Tests" begin
    @testset "validate_positive" begin
        @test Config.validate_positive(10, "test") == 10
        @test_throws ErrorException Config.validate_positive(0, "test")
        @test_throws ErrorException Config.validate_positive(-5, "test")
    end

    @testset "validate_choice" begin
        @test Config.validate_choice(:a, [:a, :b], "test") == :a
        @test_throws ErrorException Config.validate_choice(:c, [:a, :b], "test")
    end

    @testset "validate_boundary_params" begin
        # Circle (valid)
        Config.validate_boundary_params(:Circle, Dict(:radius => 10.0), 2)
        # Circle (invalid)
        @test_throws ErrorException Config.validate_boundary_params(:Circle, Dict(), 2)
        @test_throws ErrorException Config.validate_boundary_params(:Circle, Dict(:radius => -1.0), 2)

        # Box 2D (valid)
        Config.validate_boundary_params(:Box, Dict(:width => 10, :height => 10), 2)
        # Box 2D (invalid)
        @test_throws ErrorException Config.validate_boundary_params(:Box, Dict(:width => 10), 2)

        # Box 3D (valid)
        Config.validate_boundary_params(:Box, Dict(:width => 10, :height => 10, :depth => 10), 3)
        # Box 3D (invalid - missing depth)
        @test_throws ErrorException Config.validate_boundary_params(:Box, Dict(:width => 10, :height => 10), 3)
    end

    @testset "validate_gravity_params" begin
        # Uniform (valid)
        Config.validate_gravity_params(:Uniform, Dict(:vector => [0, -9.8]), 2)
        # Uniform (invalid dims)
        @test_throws ErrorException Config.validate_gravity_params(:Uniform, Dict(:vector => [0, -9.8, 0]), 2)
        # Uniform (missing vector)
         @test_throws ErrorException Config.validate_gravity_params(:Uniform, Dict(), 2)

        # Central (valid)
        Config.validate_gravity_params(:Central, Dict(:strength => 100), 2)
        # Central (missing strength)
        @test_throws ErrorException Config.validate_gravity_params(:Central, Dict(), 2)
    end
end

@testset "Config Factory Tests" begin
    # Helper to create a dummy config with minimal overrides
    function make_cfg(; kwargs...)
        base_cfg = Config.SimulationConfig(
            :Spiral, Dict(), 10.0, 2, 0.01f0, :CCD, Dict(),
            :Zero, Dict(), :Circle, Dict(:radius => 10.0),
            :interactive, "out", 800, 60, 1, "xy", Common.VisualizationConfig()
        )
        return Config.modify_config(base_cfg; kwargs...)
    end

    @testset "create_scenario" begin
        # Spiral 2D
        cfg2d = make_cfg(scenario_type=:Spiral, dimensions=2, scenario_params=Dict(:N=>100))
        scen = Config.create_scenario(cfg2d)
        @test scen isa Scenarios.SpiralScenario
        @test scen.N == 100

        # Spiral 3D
        cfg3d = make_cfg(scenario_type=:Spiral, dimensions=3, scenario_params=Dict(:N=>50))
        scen3d = Config.create_scenario(cfg3d)
        @test scen3d isa Scenarios.SpiralScenario3D
        @test scen3d.N == 50

        # Tumbler
        cfg_tumb = make_cfg(scenario_type=:Tumbler, scenario_params=Dict(:N=>200))
        scen_tumb = Config.create_scenario(cfg_tumb)
        @test scen_tumb isa Scenarios.TumblerScenario
    end

    @testset "create_boundary" begin
        # Circle 2D
        cfg = make_cfg(boundary_type=:Circle, boundary_params=Dict(:radius=>5.0), dimensions=2)
        b = Config.create_boundary(cfg)
        @test b isa Shapes.Circle
        @test b.radius == 5.0f0

        # Box 3D
        cfg3 = make_cfg(boundary_type=:Box, boundary_params=Dict(:width=>1, :height=>2, :depth=>3), dimensions=3)
        b3 = Config.create_boundary(cfg3)
        @test b3 isa Shapes.Box3D
    end

    @testset "create_gravity" begin
        # Uniform 2D
        cfg = make_cfg(gravity_type=:Uniform, gravity_params=Dict(:vector=>[0, -10]), dimensions=2)
        g = Config.create_gravity(cfg)
        @test g isa Fields.UniformField
        @test g.vector == [0.0f0, -10.0f0]
    end

    @testset "create_mode" begin
        # Interactive
        cfg = make_cfg(mode=:interactive)
        m = Config.create_mode(cfg)
        @test m isa Common.InteractiveMode

        # Render
        cfg_r = make_cfg(mode=:render, output_file="test_render.mp4")
        m_r = Config.create_mode(cfg_r)
        @test m_r isa Common.RenderMode
        @test m_r.outfile == "test_render.mp4"
    end
end

@testset "Integration: load_config" begin
    # Create a temporary YAML file
    tmp_path, io = mktemp(; cleanup=true)
    close(io)

    # Write valid config content
    yaml_content = """
    simulation:
      type: Spiral
      params:
        N: 50
      duration: 5.0
      dimensions: 2
    physics:
      dt: 0.005
      solver: CCD
      gravity:
        type: Uniform
        params:
          vector: [0.0, -9.8]
      boundary:
        type: Box
        params:
          width: 100.0
          height: 100.0
    output:
      mode: export
      filename: "test_output"
      visualization:
        mode: density
    """
    write(tmp_path, yaml_content)

    try
        cfg = Config.load_config(tmp_path)
        @test cfg isa Config.SimulationConfig
        @test cfg.scenario_type == :Spiral
        @test cfg.dimensions == 2
        @test cfg.dt == 0.005f0
        @test cfg.gravity_type == :Uniform
        @test cfg.output_file == "test_output"
        @test cfg.mode == :export
    finally
        rm(tmp_path, force=true)
    end
end
