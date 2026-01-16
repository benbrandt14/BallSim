module Physics

using ..Common
using StaticArrays
using LinearAlgebra
using KernelAbstractions

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

@kernel function physics_step_kernel(
    pos,
    vel,
    mass,
    active,
    collisions,
    dt_sub,
    restitution_term,
    boundary,
    gravity_func,
    t_start,
    substeps,
)
    i = @index(Global)
    if active[i]
        p = pos[i]
        v = vel[i]
        m = mass[i]
        inv_m = 1.0f0 / m
        t_local = t_start
        epsilon = 0.00001f0

        for _ = 1:substeps
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
                    collisions[i] += 1
                end
            end

            # Update local state for next substep
            p = p_new
            v = v_new
            t_local += dt_sub
        end

        # 3. Write Back (Once per frame)
        pos[i] = p
        vel[i] = v
    end
end

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
    sys::Common.BallSystem{D,T,S},
    solver::CCDSolver,
    boundary::Common.AbstractBoundary{D},
    gravity_func::G,
) where {D,T,S,G}

    dt_sub = solver.dt / solver.substeps
    restitution_term = 1.0f0 + solver.restitution
    backend = KernelAbstractions.get_backend(sys.data.pos)

    kernel = physics_step_kernel(backend)
    kernel(
        sys.data.pos,
        sys.data.vel,
        sys.data.mass,
        sys.data.active,
        sys.data.collisions,
        dt_sub,
        restitution_term,
        boundary,
        gravity_func,
        sys.t,
        solver.substeps;
        ndrange = length(sys.data.pos),
    )
    KernelAbstractions.synchronize(backend)

    sys.t += solver.dt
    sys.iter += 1
end

end
