module Vis

using ..Common
using StaticArrays
using LinearAlgebra

# 2D Version (Passthrough u/v)
function compute_density!(grid::Matrix{Float32}, sys::Common.BallSystem{2, T, S}, limit::Float64, u, v) where {T, S}
    compute_density!(grid, sys, limit)
end

function compute_density!(grid::Matrix{Float32}, sys::Common.BallSystem{2, T, S}, limit::Float64) where {T, S}
    fill!(grid, 0.0f0)
    res_x, res_y = size(grid)
    
    scale_x = res_x / (2 * limit)
    scale_y = res_y / (2 * limit)
    offset_x = limit
    offset_y = limit
    
    Threads.@threads for i in 1:length(sys.data.pos)
        @inbounds if sys.data.active[i]
            p = sys.data.pos[i]
            gx = floor(Int, (p[1] + offset_x) * scale_x) + 1
            gy = floor(Int, (p[2] + offset_y) * scale_y) + 1
            
            if 1 <= gx <= res_x && 1 <= gy <= res_y
                grid[gx, gy] += 1.0f0
            end
        end
    end
end

# 3D Version (Projection)
function compute_density!(grid::Matrix{Float32}, sys::Common.BallSystem{3, T, S}, limit::Float64, u::SVector{3, Float32}, v::SVector{3, Float32}) where {T, S}
    fill!(grid, 0.0f0)
    res_x, res_y = size(grid)

    scale_x = res_x / (2 * limit)
    scale_y = res_y / (2 * limit)
    offset_x = limit
    offset_y = limit

    Threads.@threads for i in 1:length(sys.data.pos)
        @inbounds if sys.data.active[i]
            p3 = sys.data.pos[i]

            # Project: P2D = (P . u, P . v)
            px = dot(p3, u)
            py = dot(p3, v)

            gx = floor(Int, (px + offset_x) * scale_x) + 1
            gy = floor(Int, (py + offset_y) * scale_y) + 1

            if 1 <= gx <= res_x && 1 <= gy <= res_y
                grid[gx, gy] += 1.0f0
            end
        end
    end
end

end