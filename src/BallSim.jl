module BallSim

using StaticArrays
using LinearAlgebra
using Printf
using Dates
using ProgressMeter

# Visualization & IO
using CairoMakie
using HDF5

# Sub-modules
include("Common.jl")
include("Shapes.jl")
include("Fields.jl")
include("Physics.jl")
include("Scenarios.jl")
include("SimIO.jl")
include("Vis.jl")
include("Config.jl")

export Common, Scenarios, Shapes, Fields, Physics, SimIO, Vis, Config

# ==============================================================================
# THE DRIVER
# ==============================================================================

function run_simulation(config_path::String)
    println("⚙️ Loading Configuration: $config_path")
    cfg = Config.load_config(config_path)
    run_simulation(cfg)
end

function run_simulation(cfg::Config.SimulationConfig)
    # 1. Setup Scenario (DYNAMIC NOW)
    scen = Config.create_scenario(cfg) # <--- Changed
    sys = Common.setup_system(scen)
    
    # 2. Build Physics from Config
    gravity = Config.create_gravity(cfg)
    boundary = Config.create_boundary(cfg)
    solver = Config.create_solver(cfg)
    mode = Config.create_mode(cfg)
    
    println("🚀 Initializing System...")
    println("   Particles: $(length(sys.data.pos))")
    println("   Mode:      $(typeof(mode))")
    println("   Boundary:  $(typeof(boundary))")
    println("   Field:     $(typeof(gravity))")
    println("   Solver:    dt=$(solver.dt)")

    _run_loop(sys, mode, solver, boundary, gravity, cfg.duration)
end

# --- Loop A: Interactive ---
function _run_loop(sys, mode::Common.OutputMode, solver, boundary, gravity, duration)
    if mode isa Common.InteractiveMode
        error("Interactive mode requires GLMakie. Please run `using GLMakie` in your script or REPL before starting the simulation.")
    else
        error("Unsupported OutputMode: $(typeof(mode))")
    end
end

# --- Loop B: Export ---
function _run_loop(sys, mode::Common.ExportMode, solver, boundary, gravity, duration)
    h5open(mode.outfile, "w") do file
        HDF5.attributes(file)["scenario"] = string(typeof(sys))
        HDF5.attributes(file)["dt"] = solver.dt
        
        total_steps = ceil(Int, duration / solver.dt)
        prog = Progress(total_steps, desc="Exporting HDF5: ", color=:blue)
        
        frame_idx = 1
        
        while sys.t < duration
            Physics.step!(sys, solver, boundary, gravity)
            if sys.iter % mode.interval == 0
                SimIO.save_frame(file, frame_idx, sys)
                frame_idx += 1
            end
            next!(prog)
        end
    end
    println("\n✅ Data saved to $(mode.outfile)")
end

# --- Loop C: Render ---
function _run_loop(sys, mode::Common.RenderMode, solver, boundary, gravity, duration)
    # Generic Rendering (handles 2D and 3D via projection)
    _render_loop_generic(sys, mode, solver, boundary, gravity, duration)
end

function _render_loop_generic(sys, mode, solver, boundary, gravity, duration)
    fig = Figure(size=(mode.res, mode.res), backgroundcolor=:black)
    ax = Axis(fig[1,1], aspect=DataAspect(), backgroundcolor=:black)
    hidedecorations!(ax)
    limits!(ax, -1.1, 1.1, -1.1, 1.1)

    grid = zeros(Float32, mode.res, mode.res)
    obs_grid = Observable(grid)
    heatmap!(ax, -1.1 .. 1.1, -1.1 .. 1.1, obs_grid, colormap=:magma, colorrange=(0, 5))
    arc!(ax, Point2f(0,0), 1.0, 0.0, 2π, color=:white, linewidth=2)

    total_frames = ceil(Int, duration * mode.fps)
    steps_per_frame = ceil(Int, (1.0/mode.fps) / solver.dt)
    
    println("🎥 Rendering $(total_frames) frames to $(mode.outfile)...")
    prog = Progress(total_frames, desc="Rendering Video: ", color=:magenta)
    
    record(fig, mode.outfile, 1:total_frames; framerate=mode.fps) do frame
        for _ in 1:steps_per_frame
            Physics.step!(sys, solver, boundary, gravity)
        end
        Vis.compute_density!(grid, sys, 1.1, mode.u, mode.v)
        notify(obs_grid)
        next!(prog)
    end
    println("\n✅ Video saved.")
end

function command_line_main()
    if length(ARGS) < 1
        println("Using default 'config.json'...")
        if isfile("config.json")
            run_simulation("config.json")
        else
            error("config.json not found")
        end
    else
        run_simulation(ARGS[1])
    end
end

end