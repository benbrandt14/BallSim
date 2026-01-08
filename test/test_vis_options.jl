
using Test
using BallSim
using StaticArrays
using LinearAlgebra

# Helper to expose submodules for testing
using BallSim: Common, Physics, Vis, Config

@testset "Visualization Options" begin

    @testset "BallSystem Collision Initialization" begin
        sys = Common.BallSystem(10, 2)
        @test hasproperty(sys.data, :collisions)
        @test length(sys.data.collisions) == 10
        @test all(sys.data.collisions .== 0)
    end

    @testset "Collision Counting" begin
        # Setup a simple system with a particle hitting a boundary
        sys = Common.BallSystem(1, 2)
        sys.data.pos[1] = SVector(0.99f0, 0.0f0)
        sys.data.vel[1] = SVector(1.0f0, 0.0f0) # Moving right towards boundary at x=1.0
        sys.data.active[1] = true

        solver = Physics.CCDSolver(0.1f0, 1.0f0, 1) # Large dt to ensure crossing
        boundary = BallSim.Shapes.Circle(1.0f0)
        gravity = (p, v, m, t) -> SVector(0.0f0, 0.0f0)

        # Step
        Physics.step!(sys, solver, boundary, gravity)

        # Check if collision was counted
        @test sys.data.collisions[1] > 0
    end

    @testset "Visualization Config Parsing" begin
        # Mock JSON data
        config_str = """
        {
            "simulation": {
                "type": "Spiral",
                "duration": 1.0,
                "dimensions": 2
            },
            "physics": {
                "gravity": { "type": "Zero" },
                "boundary": { "type": "Circle", "params": { "radius": 1.0 } }
            },
            "output": {
                "mode": "render",
                "visualization": {
                    "mode": "velocity",
                    "aggregation": "mean"
                }
            }
        }
        """
        path = "test_vis_config.json"
        write(path, config_str)

        cfg = Config.load_config(path)
        mode = Config.create_mode(cfg)

        @test mode isa Common.RenderMode
        @test mode.vis_config.mode == :velocity
        @test mode.vis_config.agg == :mean

        rm(path)
    end

    @testset "Compute Frame" begin
        sys = Common.BallSystem(1, 2)
        sys.data.pos[1] = SVector(0.0f0, 0.0f0)
        sys.data.vel[1] = SVector(2.0f0, 0.0f0)
        sys.data.mass[1] = 5.0f0
        sys.data.collisions[1] = 3
        sys.data.active[1] = true

        grid = zeros(Float32, 10, 10)
        limit = 1.0

        # Test Density
        Vis.compute_frame!(grid, sys, limit, Common.VisualizationConfig(mode=:density))
        center_val = grid[6, 6] # (0,0) should map to center
        @test center_val == 1.0f0

        # Test Mass
        fill!(grid, 0.0f0)
        Vis.compute_frame!(grid, sys, limit, Common.VisualizationConfig(mode=:mass))
        @test grid[6, 6] == 5.0f0

        # Test Velocity
        fill!(grid, 0.0f0)
        Vis.compute_frame!(grid, sys, limit, Common.VisualizationConfig(mode=:velocity))
        @test grid[6, 6] == 2.0f0

        # Test Collisions
        fill!(grid, 0.0f0)
        Vis.compute_frame!(grid, sys, limit, Common.VisualizationConfig(mode=:collisions))
        @test grid[6, 6] == 3.0f0
    end
end
