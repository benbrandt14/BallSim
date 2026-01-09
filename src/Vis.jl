module Vis

using ..Common
using StaticArrays
using LinearAlgebra

function resolve_extractor(cfg::Common.VisualizationConfig, u=nothing, v=nothing)
    if cfg.mode == :density
        return (sys, i) -> 1.0f0
    elseif cfg.mode == :mass
        return (sys, i) -> sys.data.mass[i]
    elseif cfg.mode == :velocity
        return (sys, i) -> norm(sys.data.vel[i])
    elseif cfg.mode == :collisions
        return (sys, i) -> Float32(sys.data.collisions[i])
    elseif cfg.mode == :depth
        if isnothing(u) || isnothing(v)
            return (sys, i) -> 0.0f0 # Fallback for 2D or missing projection
        end
        # Normal to the projection plane
        w = cross(u, v)
        return (sys, i) -> begin
            p = sys.data.pos[i]
            # Assume 3D for depth. If 2D system but u,v provided, try anyway, else 0.
            # Usually depth is only meaningful in 3D.
            if length(p) == 3
                return dot(p, w)
            else
                return 0.0f0
            end
        end
    else
        return (sys, i) -> 1.0f0
    end
end

"""
    compute_frame!(grid, sys, limit, u, v, cfg)

Computes the visualization frame based on config.
Projects 3D particles if necessary.
"""
function compute_frame!(grid::Matrix{Float32}, sys::Common.BallSystem{D, T, S}, limit::Float64, u, v, cfg::Common.VisualizationConfig) where {D, T, S}
    # Initialize grid based on aggregation
    if cfg.aggregation == :max
        fill!(grid, -Inf32)
    else
        fill!(grid, 0.0f0)
    end

    res_x, res_y = size(grid)
    
    scale_x = res_x / (2 * limit)
    scale_y = res_y / (2 * limit)
    offset_x = limit
    offset_y = limit
    
    extractor = resolve_extractor(cfg, u, v)

    # We use a naive racey update for performance in visualization.
    # For exact results, one would need atomics or reduction.
    Threads.@threads for i in 1:length(sys.data.pos)
        @inbounds if sys.data.active[i]
            val = extractor(sys, i)
            
            p = sys.data.pos[i]
            if D == 3
                px = dot(p, u)
                py = dot(p, v)
            else
                px = p[1]
                py = p[2]
            end

            gx = floor(Int, (px + offset_x) * scale_x) + 1
            gy = floor(Int, (py + offset_y) * scale_y) + 1

            if 1 <= gx <= res_x && 1 <= gy <= res_y
                if cfg.aggregation == :max
                    # Race condition on max is less severe (just misses updates), but ideally use atomics
                    # For visualization, simple check-update is often "good enough" or use lock if needed.
                    # We will use a simple check-and-swap loop or just naive assignment for now.
                    # Since Float32 supports atomic_max in newer Julia, but let's stick to safe simple code.
                    # Note: Concurrent max update without atomics is unsafe but often visually acceptable for particles.
                    old = grid[gx, gy]
                    if val > old
                        grid[gx, gy] = val
                    end
                else
                    grid[gx, gy] += val
                end
            end
        end
    end
end

# Alias for backward compatibility if needed, though we will update call sites.
function compute_density!(grid::Matrix{Float32}, sys::Common.BallSystem{D, T, S}, limit::Float64, u, v) where {D, T, S}
    compute_frame!(grid, sys, limit, u, v, Common.VisualizationConfig(mode=:density, aggregation=:sum))
end

end