module Shapes

using ..Common
using StaticArrays
using LinearAlgebra

# ==============================================================================
# 2D SHAPES
# ==============================================================================

struct Circle <: Common.AbstractBoundary{2}
    radius::Float32
end

struct Box <: Common.AbstractBoundary{2}
    width::Float32
    height::Float32
end

# ==============================================================================
# IMPLEMENTATIONS
# ==============================================================================

function Common.sdf(b::Circle, p::SVector{2}, t)
    return norm(p) - b.radius
end

function Common.normal(b::Circle, p::SVector{2}, t)
    # Simple radial normal
    return normalize(p)
end

function Common.sdf(b::Box, p::SVector{2}, t)
    # Signed Distance Box logic
    d = abs.(p) .- SVector(b.width/2, b.height/2)
    return norm(max.(d, 0.0f0)) + min(maximum(d), 0.0f0)
end

function Common.normal(b::Box, p::SVector{2}, t)
    # Numerical Gradient (Finite Difference) for robustness
    ϵ = 1e-4f0
    d0 = Common.sdf(b, p, t)
    nx = Common.sdf(b, p + SVector(ϵ, 0f0), t) - d0
    ny = Common.sdf(b, p + SVector(0f0, ϵ), t) - d0
    return normalize(SVector(nx, ny))
end

end