module Shapes
using LinearAlgebra
using StaticArrays
using ..Common

# --- Circle ---
struct Circle{T} <: Common.AbstractBoundary
    radius::T
end

Common.sdf(b::Circle, p, t) = norm(p) - b.radius
Common.normal(b::Circle, p, t) = normalize(p)

# --- Box ---
struct Box{T} <: Common.AbstractBoundary
    width::T
    height::T
end

function Common.sdf(b::Box, p, t)
    # 1. Shift p to the first quadrant (symmetry)
    # 2. Subtract half-dimensions to get distance from edge
    q = abs.(p) .- SVector(b.width / 2, b.height / 2)

    # 3. Calculate distance
    outside_dist = norm(max.(q, 0.0))
    inside_dist = min(maximum(q), 0.0)

    return outside_dist + inside_dist
end

end
