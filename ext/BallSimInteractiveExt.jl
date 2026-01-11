module BallSimInteractiveExt

using BallSim
using BallSim.Common
using BallSim.Physics
using BallSim.Vis
using GLMakie

function BallSim._run_loop(
    sys::Common.BallSystem,
    mode::Common.InteractiveMode,
    solver,
    boundary,
    gravity,
    duration,
)
    # Interactive Window using GLMakie
    fig = Figure(size = (mode.res, mode.res), backgroundcolor = :black)
    ax = Axis(fig[1, 1], aspect = DataAspect(), backgroundcolor = :black)
    hidedecorations!(ax)
    # Assuming boundary is roughly unit size or we just view unit box.
    # Ideally should be adaptive or configured.
    limits!(ax, -1.1, 1.1, -1.1, 1.1)

    grid = zeros(Float32, mode.res, mode.res)
    # Use observable for heatmap data
    obs_grid = Observable(grid)

    heatmap!(ax, -1.1 .. 1.1, -1.1 .. 1.1, obs_grid, colormap = :magma, colorrange = (0, 5))

    # Draw boundary approximation (simple circle)
    # TODO: Draw actual boundary shape
    arc!(ax, Point2f(0, 0), 1.0, 0.0, 2π, color = :white, linewidth = 2)

    display(fig)

    println("🎮 Interactive Simulation Started.")
    println("   Press Ctrl+C to stop.")

    # Main Loop
    fps = mode.fps
    steps_per_frame = ceil(Int, (1.0 / fps) / solver.dt)

    while events(fig).window_open[]
        # Physics Sub-steps
        for _ = 1:steps_per_frame
            Physics.step!(sys, solver, boundary, gravity)
        end

        # Visualization
        # Use compute_frame! from Vis module
        Vis.compute_frame!(grid, sys, 1.1, mode.u, mode.v, mode.vis_config)
        notify(obs_grid)

        sleep(1.0 / fps)
    end
end

end
