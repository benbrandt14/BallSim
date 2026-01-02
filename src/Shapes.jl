module Shapes

using ..Common
using StaticArrays
using LinearAlgebra

# ==============================================================================
# 1. BASE SHAPES
# ==============================================================================

struct Circle <: Common.AbstractBoundary{2}
    radius::Float32
end

struct Box <: Common.AbstractBoundary{2}
    width::Float32
    height::Float32
end

struct Ellipsoid <: Common.AbstractBoundary{2}
    rx::Float32
    ry::Float32
end

# ==============================================================================
# 2. MODIFIERS
# ==============================================================================

"""
    Inverted{D, B}

Wraps another boundary `B` and inverts its logic.
Used to trap particles INSIDE a shape (e.g., inside a Circle).
"""
struct Inverted{D, B <: Common.AbstractBoundary{D}} <: Common.AbstractBoundary{D}
    inner::B
end
# Convenience constructor
Inverted(b::Common.AbstractBoundary{D}) where D = Inverted{D, typeof(b)}(b)


# ==============================================================================
# 3. IMPLEMENTATIONS
# ==============================================================================

# --- Circle ---
function Common.sdf(b::Circle, p::SVector{2}, t)
    return norm(p) - b.radius
end

function Common.normal(b::Circle, p::SVector{2}, t)
    return normalize(p)
end

# --- Box ---
function Common.sdf(b::Box, p::SVector{2}, t)
    d = abs.(p) .- SVector(b.width/2, b.height/2)
    return norm(max.(d, 0.0f0)) + min(maximum(d), 0.0f0)
end

function Common.normal(b::Box, p::SVector{2}, t)
    # Gradient approximation
    ϵ = 1e-4f0
    d0 = Common.sdf(b, p, t)
    nx = Common.sdf(b, p + SVector(ϵ, 0f0), t) - d0
    ny = Common.sdf(b, p + SVector(0f0, ϵ), t) - d0
    return normalize(SVector(nx, ny))
end

# --- Ellipsoid ---
function Common.sdf(b::Ellipsoid, p::SVector{2}, t)
    # Approximation: Scale space to sphere, measure dist, scale back
    # This is not exact Euclidean distance but works for collisions
    # if the aspect ratio isn't extreme.
    
    k0 = length(p ./ SVector(b.rx, b.ry))
    k1 = length(p ./ (SVector(b.rx, b.ry).^2))
    return k0 * (k0 - 1.0f0) / k1
end

function Common.normal(b::Ellipsoid, p::SVector{2}, t)
    # Gradient of equation (x/rx)^2 + (y/ry)^2 = 1
    nx = 2 * p[1] / (b.rx^2)
    ny = 2 * p[2] / (b.ry^2)
    return normalize(SVector(nx, ny))
end

# --- Inverted Logic ---
function Common.sdf(b::Inverted, p::SVector, t)
    # Flip the sign!
    # If Circle SDF was -5 (Inside), Inverted is +5 (Safe).
    return -Common.sdf(b.inner, p, t)
end

function Common.normal(b::Inverted, p::SVector, t)
    # Flip the normal!
    # If Circle normal pointed Out, Inverted points In.
    return -Common.normal(b.inner, p, t)
end

end