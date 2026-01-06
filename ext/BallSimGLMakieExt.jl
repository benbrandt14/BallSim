module BallSimGLMakieExt

using BallSim
using BallSim.Common
using BallSim.Physics
using BallSim.Vis
using GLMakie
using Printf
using Dates
using ProgressMeter

# --- Loop A: Interactive ---
function BallSim._run_loop(sys, mode::Common.InteractiveMode, solver, boundary, gravity, duration)
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

# --- Loop C: Render ---
function BallSim._run_loop(sys, mode::Common.RenderMode, solver, boundary, gravity, duration)
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

end
