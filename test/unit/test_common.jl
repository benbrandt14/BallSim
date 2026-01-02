using Test
using BallSim.Common
using StaticArrays
using StructArrays

@testset "Unit: BallSystem Core" begin
    # 1. Test 2D Float32 (Standard)
    sys2d = Common.BallSystem(100, 2, Float32)
    @test eltype(sys2d.data.pos) == SVector{2, Float32}
    @test length(sys2d.data.pos) == 100
    @test sys2d.t == 0.0f0

    # 2. Test 3D Float64 (Expansion Requirement)
    sys3d = Common.BallSystem(50, 3, Float64)
    @test eltype(sys3d.data.pos) == SVector{3, Float64}
    
    # 3. Test SOA Layout (Memory Verification)
    @test sys3d.data isa StructArray
    
    # Verify that we can access columns directly (SOA behavior)
    # We assert that sys.data.pos is a contiguous array, not a view or generator
    @test sys3d.data.pos isa Array{SVector{3, Float64}, 1}
    @test sys3d.data.active isa Array{Bool, 1}
end