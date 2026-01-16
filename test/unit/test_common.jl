using Test
using BallSim.Common
using StaticArrays
using StructArrays

# Mock Boundary for testing default detect_collision
struct MockBoundary <: Common.AbstractBoundary{2} end
# Collision if x > 1. SDF = x - 1.
Common.sdf(::MockBoundary, p::SVector{2,Float32}, t) = p[1] - 1.0f0
Common.normal(::MockBoundary, p::SVector{2,Float32}, t) = SVector(-1.0f0, 0.0f0) # Push back to left

@testset "Unit: BallSystem Core" begin
    # 1. Test 2D Float32 (Standard)
    sys2d = Common.BallSystem(100, 2, Float32)
    @test eltype(sys2d.data.pos) == SVector{2,Float32}
    @test length(sys2d.data.pos) == 100
    @test sys2d.t == 0.0f0

    # 2. Test 3D Float64 (Expansion Requirement)
    sys3d = Common.BallSystem(50, 3, Float64)
    @test eltype(sys3d.data.pos) == SVector{3,Float64}

    # 3. Test SOA Layout (Memory Verification)
    @test sys3d.data isa StructArray

    # Verify that we can access columns directly (SOA behavior)
    # We assert that sys.data.pos is a contiguous array, not a view or generator
    @test sys3d.data.pos isa Array{SVector{3,Float64},1}
    @test sys3d.data.active isa Array{Bool,1}

    # 4. Test Base.show
    io = IOBuffer()
    Base.show(io, sys2d)
    output = String(take!(io))
    @test contains(output, "BallSystem{2, Float32}")
    @test contains(output, "N=100")
end

@testset "Unit: Output Modes" begin
    # VisualizationConfig
    vc = Common.VisualizationConfig()
    @test vc.mode == :density
    @test vc.aggregation == :sum

    vc2 = Common.VisualizationConfig(mode = :particles, aggregation = :mean)
    @test vc2.mode == :particles
    @test vc2.aggregation == :mean

    # InteractiveMode
    im = Common.InteractiveMode()
    @test im.res == 800
    @test im.u == SVector(1.0f0, 0.0f0, 0.0f0)

    # RenderMode
    rm = Common.RenderMode("out.mp4")
    @test rm.outfile == "out.mp4"
    @test rm.fps == 60

    # ExportMode
    em = Common.ExportMode("data.h5")
    @test em.outfile == "data.h5"
    @test em.interval == 1
end

@testset "Unit: Default Collision Logic" begin
    b = MockBoundary()

    # Case 1: No Collision (x = 0.5, sdf = -0.5)
    p_safe = SVector(0.5f0, 0.0f0)
    collided, dist, n = Common.detect_collision(b, p_safe, 0.0f0)
    @test !collided
    @test dist == 0.0f0
    @test n == SVector(0.0f0, 0.0f0)

    # Case 2: Collision (x = 1.5, sdf = 0.5)
    p_hit = SVector(1.5f0, 0.0f0)
    collided, dist, n = Common.detect_collision(b, p_hit, 0.0f0)
    @test collided
    @test dist ≈ 0.5f0
    @test n == SVector(-1.0f0, 0.0f0)
end
