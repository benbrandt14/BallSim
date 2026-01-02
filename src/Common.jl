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
function get_force_field end
function get_default_solver end

# ==============================================================================
# 2. CORE DATA STRUCTURES
# ==============================================================================

"""
    BallSystem{D, T, S}

Physical state.
- D: Dimensions (2, 3)
- T: Precision (Float32, Float64)
- S: Storage Type (StructArray{...}) <--- NEW PARAMETER
"""
mutable struct BallSystem{D, T, S}
    data::S
    t::T
    iter::Int

    function BallSystem(N::Int, D::Int, T::Type=Float32)
        # Initialize raw columns
        pos = zeros(SVector{D, T}, N)
        vel = zeros(SVector{D, T}, N)
        active = zeros(Bool, N)

        # Bind to StructArray
        data = StructArray((pos=pos, vel=vel, active=active))
        
        # We let the compiler infer the complex type 'S' from 'data'
        S = typeof(data)
        new{D, T, S}(data, zero(T), 0)
    end
end

function Base.show(io::IO, sys::BallSystem{D, T, S}) where {D, T, S}
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