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
# 2. OUTPUT MODES
# ==============================================================================

struct VisualizationConfig
    mode::Symbol
    aggregation::Symbol
end
VisualizationConfig(; mode = :density, aggregation = :sum) =
    VisualizationConfig(mode, aggregation)

abstract type OutputMode end

struct InteractiveMode <: OutputMode
    res::Int
    fps::Int
    u::SVector{3,Float32}
    v::SVector{3,Float32}
    vis_config::VisualizationConfig
end
InteractiveMode(;
    res = 800,
    fps = 60,
    u = SVector(1.0f0, 0.0f0, 0.0f0),
    v = SVector(0.0f0, 1.0f0, 0.0f0),
    vis_config = VisualizationConfig(),
) = InteractiveMode(res, fps, u, v, vis_config)

struct RenderMode <: OutputMode
    outfile::String
    fps::Int
    res::Int
    u::SVector{3,Float32}
    v::SVector{3,Float32}
    vis_config::VisualizationConfig
end
RenderMode(
    file;
    fps = 60,
    res = 1080,
    u = SVector(1.0f0, 0.0f0, 0.0f0),
    v = SVector(0.0f0, 1.0f0, 0.0f0),
    vis_config = VisualizationConfig(),
) = RenderMode(file, fps, res, u, v, vis_config)

struct ExportMode <: OutputMode
    outfile::String
    interval::Int
end
ExportMode(file; interval = 1) = ExportMode(file, interval)

# ==============================================================================
# 3. CORE DATA STRUCTURES
# ==============================================================================

"""
    BallSystem{D, T, S}

Physical state.
- D: Dimensions (2, 3)
- T: Precision (Float32, Float64)
- S: Storage Type (StructArray{...})
"""
mutable struct BallSystem{D,T,S}
    data::S
    t::T
    iter::Int

    function BallSystem(N::Int, D::Int, T::Type = Float32)
        pos = zeros(SVector{D,T}, N)
        vel = zeros(SVector{D,T}, N)
        mass = ones(T, N)
        active = zeros(Bool, N)
        collisions = zeros(Int, N)

        data = StructArray((
            pos = pos,
            vel = vel,
            mass = mass,
            active = active,
            collisions = collisions,
        ))

        S = typeof(data)
        new{D,T,S}(data, zero(T), 0)
    end
end

function Base.show(io::IO, sys::BallSystem{D,T,S}) where {D,T,S}
    N_active = count(sys.data.active)
    print(io, "BallSystem{$D, $T}(N=$(length(sys.data.pos)), Active=$N_active, t=$(sys.t))")
end

function sdf(b::AbstractBoundary{D}, p::SVector{D}, t) where {D}
    error("SDF not implemented for $(typeof(b))")
end

function normal(b::AbstractBoundary{D}, p::SVector{D}, t) where {D}
    error("Normal not implemented for $(typeof(b))")
end

"""
    detect_collision(boundary, p, t)

Checks for collision and returns (collided, dist, normal).
- collided: Bool, true if penetration depth > 0
- dist: Float32, penetration depth (positive means collision)
- normal: SVector, direction to resolve collision (points into the obstacle / forbidden region)

Default implementation calls `sdf` and `normal`.
"""
function detect_collision(b::AbstractBoundary{D}, p::SVector{D}, t) where {D}
    dist = sdf(b, p, t)
    if dist > 0
        n = normal(b, p, t)
        return (true, dist, n)
    else
        return (false, 0.0f0, zero(SVector{D,Float32}))
    end
end

end
