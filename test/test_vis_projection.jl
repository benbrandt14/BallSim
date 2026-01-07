using Test
using StaticArrays
using LinearAlgebra
using BallSim
using BallSim.Vis
using BallSim.Common

@testset "Visualization Projection" begin
    # Create a mock 3D system
    sys = Common.BallSystem(2, 3)
    sys.data.active .= true

    # P1 at (1, 0, 0)
    sys.data.pos[1] = SVector(1f0, 0f0, 0f0)
    # P2 at (0, 1, 0)
    sys.data.pos[2] = SVector(0f0, 1f0, 0f0)

    # Grid setup
    res = 10
    limit = 2.0
    grid = zeros(Float32, res, res)

    # 1. Project XY (u=(1,0,0), v=(0,1,0))
    # P1 -> (1, 0), P2 -> (0, 1)
    # Expected grid coords:
    # scale = 10 / 4 = 2.5
    # offset = 2
    # P1_grid: floor((1+2)*2.5)+1 = floor(7.5)+1 = 8
    # P1_y: floor((0+2)*2.5)+1 = floor(5)+1 = 6
    # P2_grid: floor((0+2)*2.5)+1 = 6
    # P2_y: floor((1+2)*2.5)+1 = 8

    u_xy = SVector(1f0, 0f0, 0f0)
    v_xy = SVector(0f0, 1f0, 0f0)

    Vis.compute_density!(grid, sys, limit, u_xy, v_xy)

    @test grid[8, 6] == 1.0f0
    @test grid[6, 8] == 1.0f0

    # 2. Project XZ (u=(1,0,0), v=(0,0,1))
    # P1 -> (1, 0), P2 -> (0, 0) (since P2.z is 0)
    # P2 should land at center (6, 6)

    u_xz = SVector(1f0, 0f0, 0f0)
    v_xz = SVector(0f0, 0f0, 1f0)

    Vis.compute_density!(grid, sys, limit, u_xz, v_xz)

    @test grid[8, 6] >= 1.0f0 # P1 is same
    @test grid[6, 6] == 1.0f0 # P2 moved to center

    # 3. Custom Projection (diagonal)
    # Project onto plane with u=(1,0,0) and v=(0, 0.707, 0.707) (45 deg YZ)
    # P2 (0,1,0) . v = 0.707
    # P2 projected y = 0.707

    u_custom = SVector(1f0, 0f0, 0f0)
    v_custom = SVector(0f0, 0.7071f0, 0.7071f0)

    fill!(grid, 0f0)
    Vis.compute_density!(grid, sys, limit, u_custom, v_custom)

    # P2 y grid: floor((0.7071 + 2) * 2.5) + 1 = floor(2.7071 * 2.5) + 1 = floor(6.76) + 1 = 7
    @test grid[6, 7] == 1.0f0
end
