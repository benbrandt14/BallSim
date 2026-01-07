using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using BallSim
using BallSim.Common
using BallSim.Physics
using BallSim.Scenarios
using BallSim.Shapes
using StaticArrays
using LinearAlgebra
using Printf

function calc_energy(sys, gravity_val, floor_y)
    ek = 0.0
    ep = 0.0
    for i in 1:length(sys.data.pos)
        if sys.data.active[i]
            v = sys.data.vel[i]
            p = sys.data.pos[i]
            speed2 = dot(v, v)
            ek += 0.5 * speed2 # assume m=1

            h = p[2] - floor_y
            ep += abs(gravity_val) * h
        end
    end
    return ek, ep
end

function run_energy_test()
    println("--- Energy Conservation Test ---")

    # 1 particle bouncing
    sys = Common.BallSystem(1, 2, Float32)
    sys.data.active[1] = true
    sys.data.pos[1] = SVector(0.0f0, 0.0f0)
    sys.data.vel[1] = SVector(5.0f0, 5.0f0)

    boundary = Shapes.Box(10.0f0, 10.0f0) # Floor at -5
    g_val = 10.0f0
    gravity = (p, v, t) -> SVector(0f0, -g_val)

    solver = Physics.CCDSolver(0.001f0, 1.0f0, 10) # 10 substeps to minimize integration error

    steps = 2000 # 2 seconds

    println("  Running for $steps steps...")

    e0_k, e0_p = calc_energy(sys, g_val, -5.0f0)
    e0 = e0_k + e0_p
    println("  Initial Energy: $e0 (K=$e0_k, P=$e0_p)")

    for i in 1:steps
        Physics.step!(sys, solver, boundary, gravity)

        if i % 200 == 0
            ek, ep = calc_energy(sys, g_val, -5.0f0)
            et = ek + ep
            drift = (et - e0) / e0 * 100
            @printf("  Step %4d: E=%.4f (Drift: %+.2f%%)\n", i, et, drift)
        end
    end
end

run_energy_test()
