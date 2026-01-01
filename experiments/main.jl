# experiments/main.jl
include("../src/Common.jl")
include("../src/Shapes.jl")
include("../src/Physics.jl")
include("../src/Vis.jl")

using .Common
using .Shapes
using .Physics
using .Vis

using CairoMakie
using StaticArrays
using Printf
using ProgressMeter
using Dates

# --- Configuration ---
const N = 500_000
const RES = 1080
const FPS = 60
const DURATION = 10
const SPEED = 0.2
const SOLVER_TYPE = :CCD
const SPREAD = 0.05f0

function run_experiment()
    # 1. Setup Sandbox
    sandbox_dir = joinpath(@__DIR__, "..", "sandbox")
    mkpath(sandbox_dir)
    timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
    base_name = "sim_$(timestamp)_$(SOLVER_TYPE)_N$(N)"
    video_path = joinpath(sandbox_dir, "$base_name.mp4")

    println("Initializing $N particles...")

    # 2. Setup System
    sys = Common.BallSystem(N, 2, Float32)

    Threads.@threads for i in 1:N
        sys.data.active[i] = true
        r = sqrt(i / N) * SPREAD
        theta = i * 2.4f0
        sys.data.pos[i] = SVector(r * cos(theta) - 0.5f0, r * sin(theta))
        sys.data.vel[i] = SVector(0.0f0, 0.0f0)
    end

    # 3. Setup Physics
    boundary = Shapes.Circle(1.0f0)
    gravity = Common.Gravity2D

    if SOLVER_TYPE == :CCD
        solver = Physics.CCDSolver(0.002f0, 1.0f0, 8)
        steps_per_frame = ceil(Int, (1 / FPS * SPEED) / solver.dt)
    else
        solver = Physics.DiscreteSolver(0.002f0, 5, 1.0f0)
        steps_per_frame = ceil(Int, (1 / FPS * SPEED) / solver.dt)
    end

    # 4. Setup Vis
    grid = zeros(Float32, RES, RES)
    obs_grid = Observable(grid)

    # Dynamic HUD (Time, Energy)
    obs_stats = Observable("Init...")

    # Static Metadata Block
    meta_str = """
    SOLVER:   $SOLVER_TYPE
    PARTICLES: $N
    SPEED:     $(SPEED)x
    DATE:      $timestamp
    """

    fig = Figure(backgroundcolor=:black, size=(RES, RES))
    ax = Axis(fig[1, 1], aspect=DataAspect(), backgroundcolor=:black)
    hidedecorations!(ax)

    # A. Heatmap (Bottom Layer)
    heatmap!(ax, -1.1 .. 1.1, -1.1 .. 1.1, obs_grid, colormap=:inferno, colorrange=(0, 3.5))

    # B. Boundary (Middle Layer - now thicker and explicitly white)
    # We draw two circles to create a slight "glow" or outline effect
    arc!(ax, Point2f(0, 0), 1.0, 0.0, 2π, color=:white, linewidth=3)
    arc!(ax, Point2f(0, 0), 1.005, 0.0, 2π, color=(:white, 0.3), linewidth=5)

    # C. HUD (Top Layer)
    # Top Left: Dynamic Stats
    text!(ax, -1.05, 1.05, text=obs_stats, color=:white, fontsize=24, align=(:left, :top), font="Monospace")

    # Top Right: Static Metadata
    text!(ax, 1.05, 1.05, text=meta_str, color=(:white, 0.7), fontsize=18, align=(:right, :top), font="Monospace")

    # 5. Render
    println("Rendering to $video_path...")
    prog = Progress(FPS * DURATION)

    record(fig, video_path, 1:(FPS*DURATION)) do frame
        for _ in 1:steps_per_frame
            Physics.step!(sys, solver, boundary, gravity)
        end

        Vis.compute_density!(grid, sys, 1.1)
        notify(obs_grid)

        active = count(sys.data.active)
        e_kin = sum(x -> x[1]^2 + x[2]^2, sys.data.vel) * 0.5f0

        obs_stats[] = @sprintf("TIME: %05.2fs\nN:    %d\nKE:   %.2e", sys.t, active, e_kin)

        next!(prog)
    end

    println("\nDone!")
end

run_experiment()
