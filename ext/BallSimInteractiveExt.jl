module BallSimInteractiveExt

using BallSim
using BallSim.Common
using GLMakie

function BallSim._run_loop(sys, mode::Common.InteractiveMode, solver, boundary, gravity, duration)
    println("Interactive mode initializing...")
    fig = Figure(size=(mode.res, mode.res))
    ax = Axis(fig[1,1], aspect=DataAspect())

    # Simple placeholder visualizer
    # In a real implementation this would update in a loop.
    # Since we can't run GLMakie here, this is mainly to satisfy the extension loading
    # and prove the structure works.

    println("Interactive Loop Started (Press Ctrl+C to stop)")
    display(fig)

    # Basic loop (this would block the REPL usually)
    try
        while sys.t < duration && isopen(fig.scene)
             Physics.step!(sys, solver, boundary, gravity)
             # Update visuals here...
             # sleep(1/mode.fps)
        end
    catch e
        if e isa InterruptException
            println("Stopped.")
        else
            rethrow(e)
        end
    end
end

end
