module SimIO

using ..Common
using HDF5
using StaticArrays
using StructArrays

"""
    save_frame(file::HDF5.File, index::Int, sys::BallSystem)

Saves the current state to the HDF5 group `/frame_{index}`.
Saves generic SVector components (x, y...) as separate arrays.
"""
function save_frame(file::HDF5.File, index::Int, sys::Common.BallSystem{D, T}) where {D, T}
    group_name = "frame_$(lpad(index, 5, '0'))"
    g = create_group(file, group_name)
    
    # Metadata
    attributes(g)["time"] = sys.t
    attributes(g)["N"] = length(sys.data.pos)
    
    # Data - We leverage the StructArray layout to write columns directly
    # This writes 'x', 'y' as separate datasets automatically if supported,
    # or we can write the raw components.
    # For HDF5 compatibility, writing a matrix (D x N) is often safest for external tools.
    
    # Strategy: Convert SOA to Matrix for generic IO
    # (D, N) matrix
    pos_mat = reinterpret(reshape, T, sys.data.pos)
    vel_mat = reinterpret(reshape, T, sys.data.vel)
    
    write(g, "pos", pos_mat)
    write(g, "vel", vel_mat)
    write(g, "active", collect(sys.data.active)) # BitVector -> Vector{Bool}
end

"""
    load_frame!(sys::BallSystem, file::HDF5.File, index::Int)

Overwrites `sys` with data from the file.
"""
function load_frame!(sys::Common.BallSystem{D, T}, file::HDF5.File, index::Int) where {D, T}
    group_name = "frame_$(lpad(index, 5, '0'))"
    if !haskey(file, group_name)
        error("Frame $index not found in file")
    end
    g = file[group_name]
    
    # Load Metadata
    sys.t = read_attribute(g, "time")
    
    # Load Data
    pos_mat = read(g, "pos") # D x N Matrix
    vel_mat = read(g, "vel")
    active_vec = read(g, "active")
    
    # Verify dimensions
    if size(pos_mat, 2) != length(sys.data.pos)
        error("Mismatch in particle count. File: $(size(pos_mat, 2)), Sys: $(length(sys.data.pos))")
    end
    
    # Copy back to SOA
    # reinterpret gives us a view that looks like SVector
    sys.data.pos .= reinterpret(reshape, SVector{D, T}, pos_mat)
    sys.data.vel .= reinterpret(reshape, SVector{D, T}, vel_mat)
    sys.data.active .= active_vec
end

end