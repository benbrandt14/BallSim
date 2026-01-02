module BallSim

using StaticArrays
using LinearAlgebra
using Printf
using Dates
using ProgressMeter

# Visualization & IO
using CairoMakie
using GLMakie
using HDF5

# Sub-modules
include("Common.jl")
include("Shapes.jl")
include("Fields.jl")
include("Physics.jl")
include("Scenarios.jl")
include("SimIO.jl")
include("Vis.jl")

export Common, Scenarios, Shapes, Fields, Physics, SimIO, Vis

# ==============================================================================
# 1. OUTPUT MODES
# ==============================================================================

abstract type OutputMode end

struct InteractiveMode <: OutputMode
    res::Int
    fps::Int
end
InteractiveMode(; res=800, fps=60) = InteractiveMode(res, fps)

struct RenderMode <: OutputMode
    outfile::String
    fps::Int
    res::Int
end
RenderMode(file; fps=60, res=1080) = RenderMode(file, fps, res)

struct ExportMode <: OutputMode
    outfile::String
    interval::Int
end
ExportMode(file; interval=1) = ExportMode(file, interval)


# ==============================================================================
# 2. THE DRIVER
# ==============================================================================

function run_simulation(scen::Common.AbstractScenario{D}, mode::OutputMode; duration=10.0) where D
    println("Initializing System ($(typeof(scen)))...")
    
    sys = Common.setup_system(scen)
    
    # Physics Config
    gravity = Common.get_force_field(scen)
    solver = Common.get_default_solver(scen)
    
    # We still use a default boundary here, but ideally this moves to Scenario too
    boundary = Shapes.Circle(1.0f0) 
    
    println("   Particles: $(length(sys.data.pos))")
    println("   Mode:      $(typeof(mode))")

    _run_loop(sys, mode, solver, boundary, gravity, duration)
end

# --- Loop A: Interactive (The Lab) ---
function _run_loop(sys, mode::InteractiveMode, solver, boundary, gravity, duration)
    # 1. Setup Window
    fig = Figure(size=(mode.res, mode.res), backgroundcolor=:black)
    ax = Axis(fig[1,1], aspect=DataAspect(), backgroundcolor=:black, title="Initializing...")
    hidedecorations!(ax)
    limits!(ax, -1.1, 1.1, -1.1, 1.1)

    # 2. Setup Data
    grid = zeros(Float32, mode.res, mode.res)
    obs_grid = Observable(grid)
    heatmap!(ax, -1.1 .. 1.1, -1.1 .. 1.1, obs_grid, colormap=:inferno, colorrange=(0, 5))
    arc!(ax, Point2f(0,0), 1.0, 0.0, 2π, color=:white, linewidth=2)

    println("🔴 Live View Active. Window should appear shortly.")
    display(fig)
    
    # 3. Loop with Instrumentation
    fps_target = mode.fps
    steps_per_frame = ceil(Int, (1.0/fps_target) / solver.dt)
    
    frame_count = 0
    t_last = time()
    
    while isopen(fig.scene) && sys.t < duration
        t_start = time_ns()
        
        # A. Physics Step
        for _ in 1:steps_per_frame
            Physics.step!(sys, solver, boundary, gravity)
        end
        t_phys = time_ns()
        
        # B. Vis Step
        Vis.compute_density!(grid, sys, 1.1)
        notify(obs_grid)
        t_vis = time_ns()
        
        # C. Instrumentation
        frame_count += 1
        if frame_count % 10 == 0
            dur_phys = (t_phys - t_start) / 1e6 # ms
            dur_vis  = (t_vis - t_phys) / 1e6  # ms
            total_ms = dur_phys + dur_vis
            
            # Update Title with Stats
            ax.title = @sprintf("T=%.2f | Phys: %.1fms | Vis: %.1fms | FPS: %.1f", 
                                sys.t, dur_phys, dur_vis, 1000/total_ms)
        end
        
        # D. Yield to UI
        sleep(0.001) 
    end
end

# --- Loop B: Export (The Archive) ---
function _run_loop(sys, mode::ExportMode, solver, boundary, gravity, duration)
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

# --- Loop C: Render (The Stream) ---
function _run_loop(sys, mode::RenderMode, solver, boundary, gravity, duration)
    # Headless setup
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
    args = ARGS
    
    N = 100_000
    duration = 5.0
    mode_str = "interactive"
    
    i = 1
    while i <= length(args)
        if args[i] == "--N" N = parse(Int, args[i+1]); i+=1
        elseif args[i] == "--duration" duration = parse(Float64, args[i+1]); i+=1
        elseif args[i] == "--mode" mode_str = args[i+1]; i+=1
        end
        i += 1
    end
    
    scenario = Scenarios.SpiralScenario(N=N)
    
    if mode_str == "interactive"
        mode = InteractiveMode(res=800)
    elseif mode_str == "export"
        mkpath("sandbox")
        mode = ExportMode("sandbox/data_$(Dates.format(now(), "HHMMSS")).h5", interval=10)
    elseif mode_str == "render"
        mkpath("sandbox")
        mode = RenderMode("sandbox/video_$(Dates.format(now(), "HHMMSS")).mp4", fps=60)
    else
        error("Unknown mode: $mode_str")
    end
    
    run_simulation(scenario, mode; duration=duration)
end

end