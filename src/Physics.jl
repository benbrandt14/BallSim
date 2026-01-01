module Physics
using LinearAlgebra
using StaticArrays
using ..Common

# --- Solver 1: Discrete (Symplectic Euler) ---
struct DiscreteSolver{T} <: Common.AbstractSolver
    dt::T
    substeps::Int
    restitution::T
end

function step!(sys::Common.BallSystem{D,T}, solver::DiscreteSolver, boundary, force_fn) where {D,T}
    dt_sub = solver.dt / solver.substeps

    pos = sys.data.pos
    vel = sys.data.vel
    act = sys.data.active

    for _ in 1:solver.substeps
        sys.t += dt_sub
        Threads.@threads for i in eachindex(pos)
            if !act[i]
                continue
            end

            # 1. Integration
            acc = force_fn(pos[i], vel[i], sys.t)
            vel[i] += acc * dt_sub
            pos[i] += vel[i] * dt_sub

            # 2. Boundary Check
            d = Common.sdf(boundary, pos[i], sys.t)

            if d > 0
                n = Common.normal(boundary, pos[i], sys.t)
                vn = dot(vel[i], n)
                if vn > 0 # Moving out
                    vel[i] -= (1 + solver.restitution) * vn * n
                end
                pos[i] -= n * (d * 1.001f0)
            end
        end
    end
end

# --- Solver 2: Continuous Collision Detection (CCD) ---
struct CCDSolver{T} <: Common.AbstractSolver
    dt::T
    restitution::T
    max_iter::Int
end

function step!(sys::Common.BallSystem{D,T}, solver::CCDSolver, boundary, force_fn) where {D,T}
    pos = sys.data.pos
    vel = sys.data.vel
    act = sys.data.active
    sys.t += solver.dt

    Threads.@threads for i in eachindex(pos)
        if !act[i]
            continue
        end

        t_rem = solver.dt
        iter = 0

        # Adaptive Sub-stepping Loop
        while t_rem > 1.0f-6 && iter < solver.max_iter
            iter += 1

            # 1. Determine safe step size
            # How fast are we going?
            speed = norm(vel[i])

            # How far to the wall?
            d = Common.sdf(boundary, pos[i], sys.t)

            # We want to step as far as possible, but not through the wall.
            # If d < 0 (inside), we are "safe" to move (we are leaving or inside bulk).
            # If d > 0 (outside/at wall), we need to be careful.
            # Note: Our SDF convention is: + is OUTSIDE, - is INSIDE.
            # Wait, check Shapes.jl...
            # Circle: norm(p) - r.
            #   Inside (r=1, p=0) -> -1. (Negative Inside).
            #   Surface -> 0.
            #   Outside -> Positive.

            # Wait, if we are inside (negative distance), we don't need to limit step
            # unless we are about to cross OUT (to positive).
            # The previous logic used abs(d). Let's stick to that for safety.

            dist_to_surface = abs(d)

            # Conservative step: Move 90% of the distance to the wall
            # or the full time step if we are far away.
            max_step_dist = max(dist_to_surface, 1.0f-4) # Don't get stuck in Zeno's paradox

            time_to_wall = max_step_dist / (speed + 1.0f-5)
            step_time = min(t_rem, time_to_wall)

            # 2. Integrate for this sub-step
            acc = force_fn(pos[i], vel[i], sys.t)
            vel[i] += acc * step_time
            pos[i] += vel[i] * step_time
            t_rem -= step_time

            # 3. Collision Resolution
            # Are we crossing the boundary? (SDF becomes positive)
            d_new = Common.sdf(boundary, pos[i], sys.t)

            if d_new > -1.0f-4 # We are effectively at or past surface
                n = Common.normal(boundary, pos[i], sys.t)
                vn = dot(vel[i], n)

                if vn > 0 # Moving towards the outside (escaping)
                    # Reflect
                    vel[i] -= (1 + solver.restitution) * vn * n

                    # Nudge back inside slightly to prevent "sticking"
                    pos[i] -= n * 1.0f-4
                end
            end
        end
    end
end

end
