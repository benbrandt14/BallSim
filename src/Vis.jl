module Vis

using ..Common
using StaticArrays
using LinearAlgebra

# Accessors
get_density(sys, i) = 1.0f0
get_mass(sys, i) = Float32(sys.data.mass[i])
get_velocity(sys, i) = norm(sys.data.vel[i])
get_collisions(sys, i) = Float32(sys.data.collisions[i])

function resolve_extractor(mode::Symbol)
    if mode == :mass
        return get_mass
    elseif mode == :velocity
        return get_velocity
    elseif mode == :collisions
        return get_collisions
    else
        return get_density
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
    
    extractor = resolve_extractor(config.mode)

    Threads.@threads for i in 1:length(sys.data.pos)
        @inbounds if sys.data.active[i]
            p = sys.data.pos[i]
            gx = floor(Int, (p[1] + offset_x) * scale_x) + 1
            gy = floor(Int, (p[2] + offset_y) * scale_y) + 1
            
            if 1 <= gx <= res_x && 1 <= gy <= res_y
                val = extractor(sys, i)
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

    extractor = resolve_extractor(config.mode)

    Threads.@threads for i in 1:length(sys.data.pos)
        @inbounds if sys.data.active[i]
            p3 = sys.data.pos[i]

            # Project: P2D = (P . u, P . v)
            px = dot(p3, u)
            py = dot(p3, v)

            gx = floor(Int, (px + offset_x) * scale_x) + 1
            gy = floor(Int, (py + offset_y) * scale_y) + 1

            if 1 <= gx <= res_x && 1 <= gy <= res_y
                val = extractor(sys, i)
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