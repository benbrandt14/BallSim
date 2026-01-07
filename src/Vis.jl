module Vis

using ..Common
using StaticArrays
using LinearAlgebra

@inline function get_particle_value(sys::Common.BallSystem{D, T, S}, i::Int, mode::Symbol) where {D, T, S}
    if mode == :density
        return 1.0f0
    elseif mode == :mass
        return Float32(sys.data.mass[i])
    elseif mode == :velocity
        return norm(sys.data.vel[i])
    elseif mode == :collisions
        return Float32(sys.data.collisions[i])
    else
        return 1.0f0 # Fallback to density
    end
end

# 2D Version (Passthrough u/v)
function compute_frame!(grid::Matrix{Float32}, sys::Common.BallSystem{2, T, S}, limit::Float64, u, v, config::Common.VisualizationConfig) where {T, S}
    compute_frame!(grid, sys, limit, config)
end

function compute_frame!(grid::Matrix{Float32}, sys::Common.BallSystem{2, T, S}, limit::Float64, config::Common.VisualizationConfig) where {T, S}
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
                val = get_particle_value(sys, i, config.mode)
                grid[gx, gy] += val
            end
        end
    end
end

# 3D Version (Projection)
function compute_frame!(grid::Matrix{Float32}, sys::Common.BallSystem{3, T, S}, limit::Float64, u::SVector{3, Float32}, v::SVector{3, Float32}, config::Common.VisualizationConfig) where {T, S}
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
                val = get_particle_value(sys, i, config.mode)
                grid[gx, gy] += val
            end
        end
    end
end

# Deprecated / Alias for backwards compat (if used elsewhere)
function compute_density!(grid::Matrix{Float32}, sys, limit, args...)
    compute_frame!(grid, sys, limit, args..., Common.VisualizationConfig(mode=:density, agg=:sum))
end

end