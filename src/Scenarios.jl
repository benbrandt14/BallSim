module Scenarios

using ..Common
using StaticArrays
using LinearAlgebra

# ==============================================================================
# 1. INTERFACE IMPLEMENTATION
# ==============================================================================

# Generic "System Factory" that any Scenario can use
function Common.setup_system(scen::Common.AbstractScenario{D}) where D
    # Create an empty system based on the scenario's params
    sys = Common.BallSystem(scen.N, D, Float32)
    
    # Delegate to the specific initialization logic
    initialize!(sys, scen)
    
    return sys
end

# ==============================================================================
# 2. CONCRETE SCENARIOS
# ==============================================================================

"""
    SpiralScenario(N=1000)

A simple test scenario creating a spiral distribution.
"""
struct SpiralScenario <: Common.AbstractScenario{2}
    N::Int
end
# Constructor with defaults
SpiralScenario(; N=1000) = SpiralScenario(N)

function initialize!(sys::Common.BallSystem{2}, scen::SpiralScenario)
    # The factory logic
    spread = 0.05f0
    
    for i in 1:scen.N
        sys.data.active[i] = true
        r = sqrt(i / scen.N) * spread
        theta = i * 2.4f0
        
        # Write to SOA
        sys.data.pos[i] = SVector(r * cos(theta), r * sin(theta))
        sys.data.vel[i] = SVector(0f0, 0f0)
    end
end

end