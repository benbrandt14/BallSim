using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using BallSim
using BallSim.Common
using BallSim.Physics
using BallSim.Scenarios
using BallSim.Shapes
using Printf
using StaticArrays

function run_perf()
    N = 100_000
    println("--- Performance Test (N=$N) ---")

    scen = Scenarios.SpiralScenario(N=N)
    sys = Common.setup_system(scen)

    # Force single thread or check threads
    println("  Threads: $(Threads.nthreads())")

    # Setup simple physics
    boundary = Shapes.Circle(100.0f0)
    solver = Physics.CCDSolver(0.002f0, 1.0f0, 4) # 4 substeps
    gravity = (p, v, t) -> SVector(0f0, -3.0f0)

    # Warmup
    println("  Warming up...")
    Physics.step!(sys, solver, boundary, gravity)

    steps = 100
    println("  Running $steps steps...")

    t_start = time_ns()
    for _ in 1:steps
        Physics.step!(sys, solver, boundary, gravity)
    end
    t_end = time_ns()

    dur_sec = (t_end - t_start) / 1e9
    fps = steps / dur_sec
    pps = (N * steps * solver.substeps) / dur_sec # Particle updates per second

    println("  Duration: $(round(dur_sec, digits=3))s")
    println("  FPS:      $(round(fps, digits=1))")
    println("  Updates/s: $(round(pps / 1e6, digits=2)) Million")
end

run_perf()
