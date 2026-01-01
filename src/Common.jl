module Common

using StaticArrays
using StructArrays

# ==============================================================================
# 1. ABSTRACT INTERFACES
# ==============================================================================

"""
    AbstractScenario{D}

The recipe for a simulation in D dimensions.
"""
abstract type AbstractScenario{D} end

"""
    AbstractBoundary{D}

A geometric constraint in D dimensions.
"""
abstract type AbstractBoundary{D} end

abstract type AbstractSolver end

# ==============================================================================
# 2. CORE DATA STRUCTURES
# ==============================================================================

"""
    BallSystem{D, T}

The physical state of N particles in D dimensions with precision T.
Uses StructArrays for SOA (Structure of Arrays) memory layout.
"""
mutable struct BallSystem{D, T}
    # We map the concept of a "Particle" to a collection of arrays
    data::StructArray{
        NamedTuple{(:pos, :vel, :active), 
        Tuple{SVector{D, T}, SVector{D, T}, Bool}}
    }
    t::T
    iter::Int

    function BallSystem(N::Int, D::Int, T::Type=Float32)
        # 1. Create Raw Columns
        # We explicitly create columns to ensure they are contiguous
        pos = zeros(SVector{D, T}, N)
        vel = zeros(SVector{D, T}, N)
        active = zeros(Bool, N)

        # 2. Bind into StructArray
        # This allows sys.data.pos[i] (convenience) AND sys.data.pos.x (fast access)
        data = StructArray((pos=pos, vel=vel, active=active))
        
        new{D, T}(data, zero(T), 0)
    end
end

# Helper to expose interfaces cleanly
function Base.show(io::IO, sys::BallSystem{D, T}) where {D, T}
    N_active = count(sys.data.active)
    print(io, "BallSystem{$D, $T}(N=$(length(sys.data.pos)), Active=$N_active, t=$(sys.t))")
end

# Required interfaces for Boundaries
function sdf(b::AbstractBoundary{D}, p::SVector{D}, t) where D
    error("SDF not implemented for $(typeof(b))")
end

function normal(b::AbstractBoundary{D}, p::SVector{D}, t) where D
    error("Normal not implemented for $(typeof(b))")
end

end