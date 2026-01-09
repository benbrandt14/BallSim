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

The main physics loop. Updates particle positions and velocities based on:
1.  Gravity / Force Fields
2.  Explicit Euler Integration
3.  Continuous Collision Detection (approximate via substeps) with the Boundary.

# Arguments
- `sys`: The `BallSystem` containing particle data.
- `solver`: The `CCDSolver` configuration (dt, restitution, substeps).
- `boundary`: The geometric boundary (e.g., Circle, Box).
- `gravity_func`: A callable `f(p, v, m, t)` returning force vector.

# Example
```jldoctest
julia> using BallSim, StaticArrays

julia> sys = Common.BallSystem(1, 2); # 1 particle, 2D

julia> sys.data.pos[1] = SVector(0.0f0, 0.0f0);

julia> sys.data.vel[1] = SVector(1.0f0, 0.0f0);

julia> sys.data.active[1] = true;

julia> solver = Physics.CCDSolver(0.1f0, 1.0f0, 1);

julia> boundary = Shapes.Circle(10.0f0);

julia> gravity = (p, v, m, t) -> SVector(0.0f0, -9.8f0); # Simple gravity

julia> Physics.step!(sys, solver, boundary, gravity);

julia> sys.t ≈ 0.1f0
true

julia> sys.data.pos[1][2] < 0.0f0 # Moved down due to gravity
true
```
"""
function step!(
    sys::Common.BallSystem{D, T, S}, 
    solver::CCDSolver, 
    boundary::Common.AbstractBoundary{D}, 
    gravity_func::G
) where {D, T, S, G}
    
    dt_sub = solver.dt / solver.substeps
    epsilon = 0.00001f0
    restitution_term = 1.0f0 + solver.restitution
    
    Threads.@threads for i in 1:length(sys.data.pos)
        @inbounds if sys.data.active[i]
            p = sys.data.pos[i]
            v = sys.data.vel[i]
            m = sys.data.mass[i]
            inv_m = 1.0f0 / m
            t_local = sys.t

            for _ in 1:solver.substeps
                # 1. Integration
                f = gravity_func(p, v, m, t_local)
                a = f * inv_m
                v_new = v + a * dt_sub
                p_new = p + v_new * dt_sub
                
                # 2. Collision Detection
                collided, dist, n = Common.detect_collision(boundary, p_new, t_local)
                
                if collided
                    p_new = p_new - n * (dist + epsilon)
                    
                    v_normal = dot(v_new, n)
                    if v_normal > 0
                        v_new = v_new - restitution_term * v_normal * n
                        # Count collision
                        @inbounds sys.data.collisions[i] += 1
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