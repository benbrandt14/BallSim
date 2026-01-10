module SimIO

using ..Common
using HDF5
using WriteVTK
using StaticArrays
using StructArrays

"""
    save_frame(file::HDF5.File, index::Int, sys::BallSystem)

Saves the current state to the HDF5 group `/frame_{index}`.
Saves generic SVector components (x, y...) as separate arrays.
"""
function save_frame(file::HDF5.File, index::Int, sys::Common.BallSystem{D,T}) where {D,T}
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
function load_frame!(sys::Common.BallSystem{D,T}, file::HDF5.File, index::Int) where {D,T}
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
        error(
            "Mismatch in particle count. File: $(size(pos_mat, 2)), Sys: $(length(sys.data.pos))",
        )
    end

    # Copy back to SOA
    # reinterpret gives us a view that looks like SVector
    sys.data.pos .= reinterpret(reshape, SVector{D,T}, pos_mat)
    sys.data.vel .= reinterpret(reshape, SVector{D,T}, vel_mat)
    sys.data.active .= active_vec
end

"""
    save_vtk(prefix::String, index::Int, sys::BallSystem)

Saves the current state to a VTK file (UnstructuredGrid .vtu by default).
"""
function save_vtk(prefix::String, index::Int, sys::Common.BallSystem{D,T}) where {D,T}
    # Clean prefix
    if endswith(prefix, ".vtp") || endswith(prefix, ".vtu")
        prefix = prefix[1:(end-4)]
    end

    filename = "$(prefix)_$(lpad(index, 5, '0'))"

    # 1. Prepare Points (3 x N)
    # WriteVTK expects standard Array, and preferably 3D points
    pos_flat = reinterpret(reshape, T, sys.data.pos)
    N = length(sys.data.pos)

    if D == 2
        points = zeros(T, 3, N)
        points[1:2, :] .= pos_flat
    else
        points = Array(pos_flat)
    end

    # 2. Define Cells (Vertices)
    # Using VTK_VERTEX to define each point as a cell
    cells = [MeshCell(VTKCellTypes.VTK_VERTEX, [i]) for i = 1:N]

    # 3. Create Grid
    vtk = vtk_grid(filename, points, cells)

    # 4. Add Data
    vel_flat = reinterpret(reshape, T, sys.data.vel)
    if D == 2
        vel_3d = zeros(T, 3, N)
        vel_3d[1:2, :] .= vel_flat
        vtk["Velocity"] = vel_3d
    else
        vtk["Velocity"] = Array(vel_flat)
    end

    vtk["Mass"] = sys.data.mass
    vtk["Active"] = Int.(collect(sys.data.active))
    vtk["Collisions"] = sys.data.collisions
    vtk["Time", VTKFieldData()] = sys.t

    return vtk_save(vtk)
end

end
