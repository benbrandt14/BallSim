module Physics

using ..Common
using StaticArrays
using LinearAlgebra

# ==============================================================================
# SOLVERS
# ==============================================================================

struct CCDSolver <: Common.AbstractSolver
    dt::Float32
    restitution::Float32
    substeps::Int
end

# ==============================================================================
# KERNELS
# ==============================================================================

"""
    step!(sys, solver, boundary, gravity_func)

The main physics loop. 
"""
function step!(
    sys::Common.BallSystem{D, T, S}, 
    solver::CCDSolver, 
    boundary::Common.AbstractBoundary{D}, 
    # FIX: Removed ::Function type constraint to allow callable structs (Fields)
    gravity_func 
) where {D, T, S}
    
    dt_sub = solver.dt / solver.substeps
    epsilon = 0.00001f0 
    
    # ⚡ OPTIMIZATION: Loop Inversion & Threading
    # We move the 'substeps' loop INSIDE the threaded particle loop.
    # Benefits:
    # 1. Reduces thread synchronization/spawning overhead by factor of 'substeps' (e.g., 8x).
    # 2. Keeps particle state (p, v) in CPU registers/L1 cache for all substeps.
    # 3. Reduces memory writes to sys.data (only write back once per frame).

    Threads.@threads for i in 1:length(sys.data.pos)
        @inbounds if sys.data.active[i]
            p = sys.data.pos[i]
            v = sys.data.vel[i]
            t_local = sys.t

            for _ in 1:solver.substeps
                # 1. Integration
                f = gravity_func(p, v, t_local)
                v_new = v + f * dt_sub
                p_new = p + v_new * dt_sub
                
                # 2. Collision Detection
                dist = Common.sdf(boundary, p_new, t_local)
                
                if dist > 0
                    n = Common.normal(boundary, p_new, t_local)
                    p_new = p_new - n * (dist + epsilon)
                    
                    v_normal = dot(v_new, n)
                    if v_normal > 0
                        r = 1.0f0 + solver.restitution
                        v_new = v_new - r * v_normal * n
                    end
                end
                
                # Update local state for next substep
                p = p_new
                v = v_new
                t_local += dt_sub
            end

            # 3. Write Back (Once per frame)
            @inbounds sys.data.pos[i] = p
            @inbounds sys.data.vel[i] = v
        end
    end

    sys.t += solver.dt
    sys.iter += 1
end

end