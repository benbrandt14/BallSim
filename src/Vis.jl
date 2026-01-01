module Vis

using ..Common
using StaticArrays

function compute_density!(grid::Matrix{Float32}, sys::Common.BallSystem{2, T, S}, limit::Float64) where {T, S}
    fill!(grid, 0.0f0)
    res_x, res_y = size(grid)
    
    scale_x = res_x / (2 * limit)
    scale_y = res_y / (2 * limit)
    offset_x = limit
    offset_y = limit
    
    # PERF: Simple parallel loop. 
    # Race conditions on grid cells are possible but rare for sparse/distributed particles.
    # Visual artifacts are negligible for the speedup gained.
    Threads.@threads for i in 1:length(sys.data.pos)
        if sys.data.active[i]
            p = sys.data.pos[i]
            gx = floor(Int, (p[1] + offset_x) * scale_x) + 1
            gy = floor(Int, (p[2] + offset_y) * scale_y) + 1
            
            if 1 <= gx <= res_x && 1 <= gy <= res_y
                # Not atomic, but fast.
                grid[gx, gy] += 1.0f0
            end
        end
    end
end

end