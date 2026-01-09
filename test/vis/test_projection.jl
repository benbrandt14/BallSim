using Test
using BallSim
using StaticArrays
using LinearAlgebra

@testset "Visualization Projection & Depth" begin
    # Create a dummy system
    sys = BallSim.Common.BallSystem(2, 3, Float32)
    sys.data.pos[1] = SVector(1.0f0, 0.0f0, 5.0f0) # x=1, z=5
    sys.data.pos[2] = SVector(-1.0f0, 2.0f0, -2.0f0)
    sys.data.active[1] = true
    sys.data.active[2] = true

    # Limit = 10, Res = 20x20
    # Center (0,0) -> (10, 10) in grid
    limit = 10.0
    grid = zeros(Float32, 20, 20)

    @testset "XY Projection" begin
        # Standard XY
        u = SVector(1f0, 0f0, 0f0)
        v = SVector(0f0, 1f0, 0f0)

        cfg = BallSim.Common.VisualizationConfig(mode=:density, aggregation=:sum)
        BallSim.Vis.compute_frame!(grid, sys, limit, u, v, cfg)

        # Point 1: (1, 0, 5) -> proj (1, 0).
        # Grid coords: (1 + 10)*1, (0 + 10)*1 -> 11, 10 (approx, depending on scale)
        # scale = 20 / 20 = 1.0. offset = 10.
        # gx = floor((1 + 10)*1) + 1 = 12
        # gy = floor((0 + 10)*1) + 1 = 11
        @test grid[12, 11] == 1.0f0

        # Point 2: (-1, 2, -2) -> proj (-1, 2)
        # gx = floor((-1 + 10)) + 1 = 10
        # gy = floor((2 + 10)) + 1 = 13
        @test grid[10, 13] == 1.0f0
    end

    @testset "XZ Projection (Top Down)" begin
        # XZ
        u = SVector(1f0, 0f0, 0f0)
        v = SVector(0f0, 0f0, 1f0)

        fill!(grid, 0.0f0)
        cfg = BallSim.Common.VisualizationConfig(mode=:density, aggregation=:sum)
        BallSim.Vis.compute_frame!(grid, sys, limit, u, v, cfg)

        # Point 1: (1, 0, 5) -> proj (1, 5)
        # gx = 12, gy = 16
        @test grid[12, 16] == 1.0f0
    end

    @testset "Depth Mode" begin
        # XY projection, measuring Depth (Z)
        u = SVector(1f0, 0f0, 0f0)
        v = SVector(0f0, 1f0, 0f0)
        # Normal w = u x v = (0,0,1) -> Z axis

        # Use Max aggregation to capture depth
        cfg = BallSim.Common.VisualizationConfig(mode=:depth, aggregation=:max)

        BallSim.Vis.compute_frame!(grid, sys, limit, u, v, cfg)

        # Point 1: (1, 0, 5). Depth = 5.0
        @test grid[12, 11] == 5.0f0

        # Point 2: (-1, 2, -2). Depth = -2.0
        @test grid[10, 13] == -2.0f0

        # Empty spots should be -Inf
        @test grid[1, 1] == -Inf32
    end
end
