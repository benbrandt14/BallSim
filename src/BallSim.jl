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
    error("InteractiveMode requires GLMakie. Please run `using GLMakie` before running the simulation.")
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
    error("RenderMode requires GLMakie. Please run `using GLMakie` before running the simulation.")
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