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
Refactored to handle the new BallSystem{D, T} signature.
"""
function step!(
    sys::Common.BallSystem{D, T}, 
    solver::CCDSolver, 
    boundary::Common.AbstractBoundary{D}, 
    gravity_func::Function
) where {D, T}
    
    dt_sub = solver.dt / solver.substeps
    
    # Iterate Substeps
    for _ in 1:solver.substeps
        
        # Parallel Loop over Structure of Arrays
        # Note: We use 1:length because SOA length is efficient
        Threads.@threads for i in 1:length(sys.data.pos)
            if sys.data.active[i]
                p = sys.data.pos[i]
                v = sys.data.vel[i]
                
                # 1. Integration (Symplectic Euler)
                f = gravity_func(p, v, sys.t)
                v_new = v + f * dt_sub
                p_new = p + v_new * dt_sub
                
                # 2. Collision Detection (SDF)
                dist = Common.sdf(boundary, p_new, sys.t)
                
                if dist > 0
                    # Collision Response
                    n = Common.normal(boundary, p_new, sys.t)
                    
                    # Project back to surface
                    p_new = p_new - n * (dist + 1e-5f0)
                    
                    # Reflect velocity
                    v_normal = dot(v_new, n)
                    if v_normal > 0
                        v_new = v_new - (1 + solver.restitution) * v_normal * n
                    end
                end
                
                # 3. Write Back
                sys.data.pos[i] = p_new
                sys.data.vel[i] = v_new
            end
        end
        
        sys.t += dt_sub
    end
    
    sys.iter += 1
end

end