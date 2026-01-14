module Fields

using StaticArrays
using LinearAlgebra

abstract type AbstractField end

# Functor interface: Field instances are callable
# (field::MyField)(p, v, m, t) -> Force Vector

# ==============================================================================
# CONCRETE FIELDS
# ==============================================================================

"""
    UniformField{D, T}

A constant force field (e.g., gravity) applied uniformly to all particles.
F = m * vector

# Example
```jldoctest
julia> using BallSim, StaticArrays

julia> g = Fields.UniformField(SVector(0.0f0, -9.8f0));

julia> g(SVector(0f0,0f0), SVector(0f0,0f0), 1.0f0, 0.0f0) == SVector(0.0f0, -9.8f0)
true
```
"""
struct UniformField{D,T} <: AbstractField
    vector::SVector{D,T}
end
(f::UniformField)(p, v, m, t) = f.vector * m

struct ViscousDrag{T} <: AbstractField
    k::T # Damping coefficient
end
(f::ViscousDrag)(p, v, m, t) = -f.k * v

struct CentralField{D,T} <: AbstractField
    center::SVector{D,T}
    strength::T
    mode::Symbol # :attractor, :repulsor
    cutoff::T    # Avoid singularity at r=0
end
CentralField(center, strength; mode = :attractor, cutoff = 0.1f0) =
    CentralField(center, strength, mode, cutoff)

function (f::CentralField)(p, v, m, t)
    diff = f.center - p
    dist_sq = dot(diff, diff)
    dist = sqrt(dist_sq)

    # Soften the core to prevent explosion at dist=0
    denom = max(dist, f.cutoff)

    # F = strength * direction
    # Attractive: points to center
    dir = diff / denom

    # F = k / r^2 (Gravity/Magnetic) or F = k * r (Spring)?
    # Let's assume Inverse Square Law for "Fields"
    mag = f.strength / (denom^2)

    force_vec = f.mode == :attractor ? (dir * mag) : -(dir * mag)
    return force_vec * m
end

"""
    VortexField{D, T}

A force field that applies a tangential force around a center.
F = (strength / r^2) * tangent_vector

# Example
```jldoctest
julia> using BallSim, StaticArrays

julia> v = Fields.VortexField(SVector(0.0f0, 0.0f0), 1.0f0);

julia> v(SVector(1.0f0, 0.0f0), SVector(0f0,0f0), 1.0f0, 0.0f0)
2-element SVector{2, Float32} with indices SOneTo(2):
 -0.0
  1.0
```
"""
struct VortexField{D,T} <: AbstractField
    center::SVector{D,T}
    strength::T
    cutoff::T
end
VortexField(center, strength; cutoff = 0.1f0) = VortexField(center, strength, cutoff)

function (f::VortexField{2})(p, v, m, t)
    diff = p - f.center
    dist_sq = dot(diff, diff)
    dist = sqrt(dist_sq)
    denom = max(dist, f.cutoff)

    # Tangent: (-y, x)
    # Normalized: (-y, x) / dist = (-y/dist, x/dist)
    # Note: diff is p - center.
    dir = SVector(-diff[2], diff[1]) / denom

    mag = f.strength / (denom^2)

    return dir * mag * m
end

function (f::VortexField{3})(p, v, m, t)
    # Cylindrical vortex around Z axis passing through center
    diff = p - f.center

    # Distance in XY plane
    dist_xy = sqrt(diff[1]^2 + diff[2]^2)
    denom = max(dist_xy, f.cutoff)

    dir = SVector(-diff[2], diff[1], 0.0f0) / denom

    mag = f.strength / (denom^2)

    return dir * mag * m
end

# ==============================================================================
# COMPOSITE FIELD
# ==============================================================================

struct CombinedField{T<:Tuple} <: AbstractField
    fields::T
end

# Fast unrolling of the tuple sum
function (c::CombinedField)(p, v, m, t)
    sum(f -> f(p, v, m, t), c.fields)
end

end
