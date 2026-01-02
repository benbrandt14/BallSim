module Scenarios

using ..Common
using ..Physics
using StaticArrays
using LinearAlgebra

# ==============================================================================
# 1. GENERIC INTERFACE IMPLEMENTATION
# ==============================================================================

# Generic factory: Sets up system, calls specific initialize!, returns system
function Common.setup_system(scen::Common.AbstractScenario{D}) where D
    sys = Common.BallSystem(scen.N, D, Float32)
    initialize!(sys, scen)
    return sys
end

# Generic fallback: Zero gravity if the scenario doesn't specify
function Common.get_force_field(scen::Common.AbstractScenario{D}) where D
    return (p, v, t) -> zero(SVector{D, Float32})
end

# ==============================================================================
# 2. CONCRETE SCENARIOS
# ==============================================================================

# --- Spiral Scenario Definition ---
struct SpiralScenario <: Common.AbstractScenario{2}
    N::Int
end
SpiralScenario(; N=1000) = SpiralScenario(N)

# --- Spiral Implementation ---

function initialize!(sys::Common.BallSystem{2, T, S}, scen::SpiralScenario) where {T, S}
    spread = 0.05f0
    
    Threads.@threads for i in 1:scen.N
        sys.data.active[i] = true
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
    # Standard Gravity pointing down
    return (p, v, t) -> SVector(0f0, -3.0f0)
end

function Common.get_default_solver(scen::SpiralScenario)
    # 2ms step, 1.0 restitution (bouncy), 8 sub-steps for precision
    return Physics.CCDSolver(0.002f0, 1.0f0, 8)
end

end