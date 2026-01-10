using Test
using BallSim.Common
using BallSim.SimIO
using HDF5
using StaticArrays

# Enforce HDF5 schema compliance and lossless data recovery.

@testset "Unit: HDF5 IO" begin
    # Setup Logic
    fname = tempname() * ".h5"
    sys_orig = Common.BallSystem(10, 2, Float32)

    # Modify state so it's not empty
    sys_orig.data.pos[1] = SVector(1.0f0, 2.0f0)
    sys_orig.data.active[1] = true
    sys_orig.t = 5.5f0

    try
        # 1. Write
        h5open(fname, "w") do file
            SimIO.save_frame(file, 1, sys_orig)
        end

        # 2. Verify Schema (External integrity)
        h5open(fname, "r") do file
            @test haskey(file, "frame_00001")
            g = file["frame_00001"]
            @test haskey(g, "pos")
            @test haskey(g, "vel")
            @test read_attribute(g, "time") ≈ 5.5f0
        end

        # 3. Read & Compare
        sys_new = Common.BallSystem(10, 2, Float32)
        h5open(fname, "r") do file
            SimIO.load_frame!(sys_new, file, 1)
        end

        @test sys_new.t ≈ sys_orig.t
        @test sys_new.data.pos[1] == sys_orig.data.pos[1]
        @test sys_new.data.active[1] == true

    finally
        rm(fname, force = true)
    end
end
