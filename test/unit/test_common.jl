using Test
using BallSim.Common
using StaticArrays
using StructArrays

# Enforce that BallSystem supports generic dimensions (D) and precision (T), and uses SOA layout.

@testset "Unit: BallSystem Core" begin
    # 1. Test 2D Float32 (Standard)
    sys2d = Common.BallSystem(100, 2, Float32)
    @test eltype(sys2d.data.pos) == SVector{2, Float32}
    @test length(sys2d.data.pos) == 100
    @test sys2d.t == 0.0f0

    # 2. Test 3D Float64 (Expansion Requirement)
    sys3d = Common.BallSystem(50, 3, Float64)
    @test eltype(sys3d.data.pos) == SVector{3, Float64}
    @test length(sys3d.data.vel) == 50
    
    # 3. Test SOA Layout (Memory Verification)
    # We verify that 'pos' is a StructArray mapping to raw columns
    @test sys3d.data.pos isa StructArray
    # Verification of column access (Crucial for HDF5/GPU)
    @test hasproperty(sys3d.data.pos, :x) 
    @test hasproperty(sys3d.data.pos, :y)
    @test hasproperty(sys3d.data.pos, :z)
end