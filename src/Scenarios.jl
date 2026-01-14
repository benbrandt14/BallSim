module Scenarios

using ..Common
using ..Physics
using StaticArrays
using LinearAlgebra

# ==============================================================================
# 1. GENERIC INTERFACE IMPLEMENTATION
# ==============================================================================

# Generic factory: Sets up system, calls specific initialize!, returns system
function Common.setup_system(scen::Common.AbstractScenario{D}) where {D}
    sys = Common.BallSystem(scen.N, D, Float32)
    initialize!(sys, scen)
    return sys
end

# Generic fallback: Zero gravity if the scenario doesn't specify
function Common.get_force_field(scen::Common.AbstractScenario{D}) where {D}
    return (p, v, m, t) -> zero(SVector{D,Float32})
end

# ==============================================================================
# 2. CONCRETE SCENARIOS
# ==============================================================================

# --- Spiral Scenario Definition ---
struct SpiralScenario <: Common.AbstractScenario{2}
    N::Int
    mass_min::Float32
    mass_max::Float32
end
SpiralScenario(; N = 1000, mass_min = 1.0f0, mass_max = 1.0f0) =
    SpiralScenario(N, mass_min, mass_max)

struct SpiralScenario3D <: Common.AbstractScenario{3}
    N::Int
    mass_min::Float32
    mass_max::Float32
end
SpiralScenario3D(; N = 1000, mass_min = 1.0f0, mass_max = 1.0f0) =
    SpiralScenario3D(N, mass_min, mass_max)

# --- Spiral Implementation (2D) ---

function initialize!(sys::Common.BallSystem{2,T,S}, scen::SpiralScenario) where {T,S}
    spread = 0.05f0

    Threads.@threads for i = 1:scen.N
        sys.data.active[i] = true
        sys.data.mass[i] = rand(T) * (scen.mass_max - scen.mass_min) + scen.mass_min
        r = sqrt(i / scen.N) * spread
        theta = i * 2.4f0

        # Position: Spiral
        p = SVector(r * cos(theta), r * sin(theta))
        sys.data.pos[i] = p

        # Velocity: Rotation (Tangent to position)
        sys.data.vel[i] = SVector(-p[2], p[1]) * 10.0f0
    end
end

function Common.get_force_field(scen::SpiralScenario)
    # Standard Gravity pointing down.
    # Returns a closure that computes Force = mass * acceleration
    # Acceleration is SVector(0f0, -3.0f0)
    return (p, v, m, t) -> SVector(0.0f0, -3.0f0) * m
end

function Common.get_default_solver(scen::SpiralScenario)
    # 2ms step, 1.0 restitution (bouncy), 8 sub-steps for precision
    return Physics.CCDSolver(0.002f0, 1.0f0, 8)
end

# --- Spiral Implementation (3D) ---

function initialize!(sys::Common.BallSystem{3,T,S}, scen::SpiralScenario3D) where {T,S}
    spread = 0.05f0

    Threads.@threads for i = 1:scen.N
        sys.data.active[i] = true
        sys.data.mass[i] = rand(T) * (scen.mass_max - scen.mass_min) + scen.mass_min
        r = sqrt(i / scen.N) * spread
        theta = i * 2.4f0
        z = (i / scen.N) * 2.0f0 - 1.0f0

        # Position: Spiral (Helix)
        p = SVector(r * cos(theta), r * sin(theta), z)
        sys.data.pos[i] = p

        # Velocity: Rotation (Tangent to position, with some Z)
        sys.data.vel[i] = SVector(-p[2], p[1], 0.0f0) * 10.0f0
    end
end

function Common.get_force_field(scen::SpiralScenario3D)
    # Standard Gravity pointing down (Z axis).
    # Acceleration is SVector(0f0, 0f0, -3.0f0)
    return (p, v, m, t) -> SVector(0.0f0, 0.0f0, -3.0f0) * m
end

function Common.get_default_solver(scen::SpiralScenario3D)
    return Physics.CCDSolver(0.002f0, 1.0f0, 8)
end

# --- Tumbler Scenario ---

struct TumblerScenario <: Common.AbstractScenario{2}
    N::Int
end
TumblerScenario(; N = 1000) = TumblerScenario(N)

function initialize!(sys::Common.BallSystem{2,T,S}, scen::TumblerScenario) where {T,S}
    # Initialize in a box [-2, 2]
    width = 4.0f0

    # Grid layout to avoid initial overlap
    rows = ceil(Int, sqrt(scen.N))
    spacing = width / rows

    offset = -width / 2.0f0 + spacing / 2.0f0

    Threads.@threads for i = 1:scen.N
        sys.data.active[i] = true
        sys.data.mass[i] = 1.0f0

        r = (i - 1) % rows
        c = (i - 1) ÷ rows

        x = offset + c * spacing
        y = offset + r * spacing

        sys.data.pos[i] = SVector(x, y)
        sys.data.vel[i] = SVector(0.0f0, 0.0f0)
    end
end

function Common.get_force_field(scen::TumblerScenario)
    return Fields.UniformField(SVector(0.0f0, -9.8f0))
end

function Common.get_default_solver(scen::TumblerScenario)
    return Physics.CCDSolver(0.002f0, 0.5f0, 8)
end

end
