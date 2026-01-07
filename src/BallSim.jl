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
include("CLI.jl")

export Common, Scenarios, Shapes, Fields, Physics, SimIO, Vis, Config, CLI

# ==============================================================================
# THE DRIVER
# ==============================================================================

function run_simulation(config_path::String, overrides::Dict{String, Any}=Dict{String, Any}())
    println("⚙️ Loading Configuration: $config_path")
    cfg = Config.load_config(config_path, overrides)
    
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
        msg = """
        Interactive mode requires GLMakie, which is not currently loaded.

        To fix this:
        1. Install/Load GLMakie: `using GLMakie`
        2. OR Use a different mode via CLI:
           ./run.sh --mode=export
           ./run.sh --mode=render
        """
        error(msg)
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
    config_file, overrides = CLI.parse_args(ARGS)

    if isempty(config_file)
         # Should not happen given CLI.jl logic defaults to config.json
         config_file = "config.json"
    end

    if !isfile(config_file)
        # If user didn't specify file but default missing
        if config_file == "config.json"
            error("Default 'config.json' not found. Please provide a config file.")
        else
            error("Config file not found: $config_file")
        end
    end

    run_simulation(config_file, overrides)
end

end