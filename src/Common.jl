module Common

using StaticArrays
using StructArrays
using LinearAlgebra

# --- Types ---
abstract type AbstractBoundary end
abstract type AbstractSolver end

# Parametric Particle: Agnostic to Dimension (D) and Precision (T)
struct Particle{D,T}
    pos::SVector{D,T}
    vel::SVector{D,T}
    active::Bool
end

# The System wrapper
mutable struct BallSystem{D,T}
    data::StructArray{Particle{D,T}}
    t::T
end

function BallSystem(n::Int, D::Int=2, T::Type=Float32)
    # Init with zeros/false
    s = StructArray{Particle{D,T}}(undef, n)
    fill!(s.active, false)
    return BallSystem(s, T(0))
end

# --- Interface Definitions ---
const Gravity2D = (p, v, t) -> SVector(0.0f0, -9.81f0)

function sdf(b::AbstractBoundary, p, t)
    error("Not Implemented")
end

function normal(b::AbstractBoundary, p, t)
    # Finite Difference fallback
    d = sdf(b, p, t)

    # Use valid Float32 scientific notation (1f-4)
    ϵ = 1.0f-4

    grad = p .* 0
    for i in 1:length(p)
        p_shifted = setindex(p, p[i] + ϵ, i)
        grad = setindex(grad, sdf(b, p_shifted, t) - d, i)
    end
    return normalize(grad)
end

end
