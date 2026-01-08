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

struct Circle3D <: Common.AbstractBoundary{3}
    radius::Float32
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
# NOTE: Removed manual convenience constructor to fix "Method overwritten" warning.
# Julia automatically generates Inverted(b) -> Inverted{D, typeof(b)}(b).

# ==============================================================================
# 3. IMPLEMENTATIONS
# ==============================================================================

# --- Circle ---
"""
    sdf(b::Circle, p::SVector{2}, t)

Signed Distance Function for a 2D Circle.
Returns negative if inside, positive if outside.

# Example
```jldoctest
julia> using BallSim, StaticArrays

julia> c = Shapes.Circle(1.0f0);

julia> Common.sdf(c, SVector(0.0f0, 0.0f0), 0.0f0)
-1.0f0

julia> Common.sdf(c, SVector(2.0f0, 0.0f0), 0.0f0)
1.0f0
```
"""
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
    # Analytical Gradient
    # Replaces previous numerical gradient which had a syntax error (1e-4f0) and was slow.

    w, h = b.width/2, b.height/2
    d = abs.(p) .- SVector(w, h)

    # Check max(d, 0) for positive components (outside box in that axis)
    d_max_x = max(d[1], 0f0)
    d_max_y = max(d[2], 0f0)

    if d_max_x > 0 || d_max_y > 0
        # Outside: normal matches direction of positive distance
        # Normal = normalize(sign(p) * max(d, 0))

        nx = copysign(d_max_x, p[1])
        ny = copysign(d_max_y, p[2])

        # Normalize
        inv_len = 1.0f0 / sqrt(nx^2 + ny^2)
        return SVector(nx * inv_len, ny * inv_len)
    else
        # Inside: normal is unit vector along max component of d (closest edge)
        if d[1] > d[2]
            return SVector(sign(p[1]), 0f0)
        else
            return SVector(0f0, sign(p[2]))
        end
    end
end

# --- Ellipsoid ---
function Common.sdf(b::Ellipsoid, p::SVector{2}, t)
    # Gradient Normalization Approximation.
    # d ≈ (f(p)) / |∇f(p)|
    # This is more accurate for elongated shapes than simple scaling.
    
    rx, ry = b.rx, b.ry
    k = norm(p ./ SVector(rx, ry))
    
    # Handle singularity at center
    if k < 1e-6
        return -min(rx, ry)
    end
    
    # ∇k = ( x / (k*rx^2), y / (k*ry^2) )
    gx = p[1] / (k * rx^2)
    gy = p[2] / (k * ry^2)
    grad_len = sqrt(gx^2 + gy^2)
    
    return (k - 1.0f0) / grad_len
end

function Common.normal(b::Ellipsoid, p::SVector{2}, t)
    # Gradient of implicit surface
    nx = 2 * p[1] / (b.rx^2)
    ny = 2 * p[2] / (b.ry^2)
    return normalize(SVector(nx, ny))
end

# --- Circle3D ---
function Common.sdf(b::Circle3D, p::SVector{3}, t)
    return norm(p) - b.radius
end

function Common.normal(b::Circle3D, p::SVector{3}, t)
    return normalize(p)
end

# --- Inverted Logic ---
function Common.sdf(b::Inverted, p::SVector, t)
    # Inside becomes Safe (+), Outside becomes Collision (-)
    return -Common.sdf(b.inner, p, t)
end

function Common.normal(b::Inverted, p::SVector, t)
    # Normal points Inward
    return -Common.normal(b.inner, p, t)
end

end