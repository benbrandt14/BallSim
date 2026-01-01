module Vis

using ..Common
using StaticArrays

"""
    compute_density!(grid, sys, limit)

Rasterizes particle positions into a density grid using coarse binning.
Maps the world space (-limit, limit) to grid indices (1, res).
"""
function compute_density!(grid::Matrix{Float32}, sys::Common.BallSystem, limit::Float64)
    # 1. Clear Grid
    fill!(grid, 0.0f0)

    res_x, res_y = size(grid)
    active_mask = sys.data.active
    positions = sys.data.pos

    # Precompute scaling factors
    # World range: [-limit, limit] -> width = 2*limit
    scale_x = res_x / (2 * limit)
    scale_y = res_y / (2 * limit)
    offset_x = limit
    offset_y = limit

    # 2. Rasterize (Simple Point Splatting)
    # Note: For massive particle counts, we avoid atomic locking by accepting
    # minor race conditions in visualization, or we can simply run single-threaded
    # if visual accuracy is paramount. For N=500k, slight noise is invisible.

    @inbounds for i in eachindex(active_mask)
        if active_mask[i]
            p = positions[i]

            # Map -limit..limit to 1..res
            gx = floor(Int, (p[1] + offset_x) * scale_x) + 1
            gy = floor(Int, (p[2] + offset_y) * scale_y) + 1

            if 1 <= gx <= res_x && 1 <= gy <= res_y
                grid[gx, gy] += 1.0f0
            end
        end
    end

    # 3. Log Compression (Optional, makes faint particles visible)
    # grid .= log1p.(grid)
end

end
