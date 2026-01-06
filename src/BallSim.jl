module BallSim

using StaticArrays
using LinearAlgebra
using Printf
using Dates
using ProgressMeter

# Visualization & IO
using CairoMakie
# using GLMakie
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
function _run_loop(sys, mode::Common.InteractiveMode, solver, boundary, gravity, duration)
    # NOTE: Updated signature to use Common.InteractiveMode
    fig = Figure(size=(mode.res, mode.res), backgroundcolor=:black)
    ax = Axis(fig[1,1], aspect=DataAspect(), backgroundcolor=:black, title="Initializing...")
    hidedecorations!(ax)
    limits!(ax, -1.1, 1.1, -1.1, 1.1)

    grid = zeros(Float32, mode.res, mode.res)
    obs_grid = Observable(grid)
    heatmap!(ax, -1.1 .. 1.1, -1.1 .. 1.1, obs_grid, colormap=:inferno, colorrange=(0, 5))
    arc!(ax, Point2f(0,0), 1.0, 0.0, 2π, color=:white, linewidth=2)

    println("🔴 Live View Active.")
    display(fig)
    
    fps_target = mode.fps
    steps_per_frame = ceil(Int, (1.0/fps_target) / solver.dt)
    
    frame_count = 0
    
    while isopen(fig.scene) && sys.t < duration
        t_start = time_ns()
        
        for _ in 1:steps_per_frame
            Physics.step!(sys, solver, boundary, gravity)
        end
        t_phys = time_ns()
        
        Vis.compute_density!(grid, sys, 1.1)
        notify(obs_grid)
        t_vis = time_ns()
        
        frame_count += 1
        if frame_count % 10 == 0
            dur_phys = (t_phys - t_start) / 1e6
            dur_vis  = (t_vis - t_phys) / 1e6
            total_ms = dur_phys + dur_vis
            ax.title = @sprintf("T=%.2f | Phys: %.1fms | Vis: %.1fms | FPS: %.1f", 
                                sys.t, dur_phys, dur_vis, 1000/total_ms)
        end
        sleep(0.001) 
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
        Vis.compute_density!(grid, sys, 1.1)
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