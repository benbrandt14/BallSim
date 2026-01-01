module BallSim

using StaticArrays
using LinearAlgebra
using Printf
using Dates
using CairoMakie
using GLMakie
using ProgressMeter

# ==============================================================================
# 1. SUB-MODULES
# ==============================================================================

include("Common.jl")
include("Scenarios.jl") # <--- Added this
include("Shapes.jl")
include("Physics.jl")
include("SimIO.jl")
include("Vis.jl")

export Common, Scenarios, Shapes, Physics, Vis

# ==============================================================================
# 2. DEMO RUNNER
# ==============================================================================

function run_demo(;
    N::Int=500_000,
    res::Int=1080,
    fps::Int=60,
    duration::Float64=10.0,
    speed::Float64=0.2,
    video_path=nothing
)
    # --- Configuration ---
    solver_type = :CCD
    spread = 0.05f0

    if isnothing(video_path)
        timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
        mkpath("sandbox")
        base_name = "sim_$(timestamp)_$(solver_type)_N$(N)"
        video_path = joinpath("sandbox", "$base_name.mp4")
    end

    println("🚀 Initializing $N particles...")

    # 1. Setup System
    sys = Common.BallSystem(N, 2, Float32)

    # Spiral Initialization for cool visual
    Threads.@threads for i in 1:N
        sys.data.active[i] = true
        r = sqrt(i / N) * spread
        theta = i * 2.4f0
        sys.data.pos[i] = SVector(r * cos(theta) - 0.5f0, r * sin(theta))
        sys.data.vel[i] = SVector(0.0f0, 0.0f0)
    end

    # 2. Setup Physics
    boundary = Shapes.Circle(1.0f0)
    gravity = Common.Gravity2D

    if solver_type == :CCD
        solver = Physics.CCDSolver(0.002f0, 1.0f0, 8)
    else
        solver = Physics.DiscreteSolver(0.002f0, 5, 1.0f0)
    end

    # Calculate sub-steps to match requested playback speed
    steps_per_frame = ceil(Int, (1.0 / fps * speed) / solver.dt)

    # 3. Setup Vis
    grid = zeros(Float32, res, res)
    obs_grid = Observable(grid)
    obs_stats = Observable("Init...")

    meta_str = """
    SOLVER:    $solver_type
    PARTICLES: $N
    SPEED:     $(speed)x
    """

    # 4. Makie Scene Setup
    fig = Figure(backgroundcolor=:black, size=(res, res))
    ax = Axis(fig[1, 1], aspect=DataAspect(), backgroundcolor=:black)
    hidedecorations!(ax)
    limits!(ax, -1.1, 1.1, -1.1, 1.1)

    # Layer A: Heatmap
    heatmap!(ax, -1.1 .. 1.1, -1.1 .. 1.1, obs_grid, colormap=:inferno, colorrange=(0, 5.0))

    # Layer B: Boundary Glow
    arc!(ax, Point2f(0, 0), 1.0, 0.0, 2π, color=:white, linewidth=3)
    arc!(ax, Point2f(0, 0), 1.005, 0.0, 2π, color=(:white, 0.3), linewidth=5)

    # Layer C: HUD
    text!(ax, -1.05, 1.05, text=obs_stats, color=:white, fontsize=24, align=(:left, :top), font="Monospace")
    text!(ax, 1.05, 1.05, text=meta_str, color=(:white, 0.7), fontsize=18, align=(:right, :top), font="Monospace")

    # 5. Render Loop
    println("📹 Rendering to $video_path...")
    prog = Progress(ceil(Int, fps * duration))

    record(fig, video_path, 1:ceil(Int, fps * duration)) do frame
        # Physics Burst
        for _ in 1:steps_per_frame
            Physics.step!(sys, solver, boundary, gravity)
        end

        # Rasterize
        Vis.compute_density!(grid, sys, 1.1)
        notify(obs_grid)

        # Update HUD
        active = count(sys.data.active)
        e_kin = sum(x -> x[1]^2 + x[2]^2, sys.data.vel) * 0.5f0
        obs_stats[] = @sprintf("TIME: %05.2fs\nN:    %d\nKE:   %.2e", sys.t, active, e_kin)

        next!(prog)
    end

    println("\n✅ Done!")
end

# ==============================================================================
# 3. CLI PARSER
# ==============================================================================

function command_line_main()
    args = ARGS

    # Defaults
    N = 5_000_000
    res = 1080
    fps = 60
    duration = 10.0
    speed = 0.2
    outfile = nothing

    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--N" || arg == "-n"
            N = parse(Int, args[i+1])
            i += 1
        elseif arg == "--res" || arg == "-r"
            res = parse(Int, args[i+1])
            i += 1
        elseif arg == "--duration" || arg == "-d"
            duration = parse(Float64, args[i+1])
            i += 1
        elseif arg == "--speed" || arg == "-s"
            speed = parse(Float64, args[i+1])
            i += 1
        elseif arg == "--fps"
            fps = parse(Int, args[i+1])
            i += 1
        elseif arg == "--out" || arg == "-o"
            outfile = args[i+1]
            i += 1
        elseif arg == "--help" || arg == "-h"
            println("BallSim CLI Usage:")
            println("  --N <int>          Number of particles (default: 500,000)")
            println("  --res <int>        Video resolution (default: 1080)")
            println("  --duration <sec>   Sim duration (default: 10.0)")
            println("  --speed <float>    Playback speed multiplier (default: 0.2)")
            return
        end
        i += 1
    end

    run_demo(N=N, res=res, fps=fps, duration=duration, speed=speed, video_path=outfile)
end

end
