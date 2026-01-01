module Common

using StaticArrays
using StructArrays

# ==============================================================================
# 1. ABSTRACT INTERFACES
# ==============================================================================

abstract type AbstractScenario{D} end
abstract type AbstractBoundary{D} end
abstract type AbstractSolver end

function setup_system end

# ==============================================================================
# 2. CORE DATA STRUCTURES
# ==============================================================================

mutable struct BallSystem{D, T}
    # Nested StructArray:
    # The top level has fields :pos, :vel, :active
    # The :pos field is ITSELF a StructArray with fields :x, :y (inherited from SVector)
    data::StructArray{
        NamedTuple{(:pos, :vel, :active), 
        Tuple{SVector{D, T}, SVector{D, T}, Bool}}
    }
    t::T
    iter::Int

    function BallSystem(N::Int, D::Int, T::Type=Float32)
        # NESTED SOA PATTERN
        # Instead of `zeros(SVector...)`, we use `StructArray(zeros...)`
        # This allocates separate arrays for x, y, z under the hood.
        pos = StructArray(zeros(SVector{D, T}, N))
        vel = StructArray(zeros(SVector{D, T}, N))
        active = zeros(Bool, N)

        data = StructArray((pos=pos, vel=vel, active=active))
        new{D, T}(data, zero(T), 0)
    end
end

function Base.show(io::IO, sys::BallSystem{D, T}) where {D, T}
    N_active = count(sys.data.active)
    print(io, "BallSystem{$D, $T}(N=$(length(sys.data.pos)), Active=$N_active, t=$(sys.t))")
end

function sdf(b::AbstractBoundary{D}, p::SVector{D}, t) where D
    error("SDF not implemented for $(typeof(b))")
end

function normal(b::AbstractBoundary{D}, p::SVector{D}, t) where D
    error("Normal not implemented for $(typeof(b))")
end

end