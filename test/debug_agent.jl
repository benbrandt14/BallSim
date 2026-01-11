# This is a tool for agents to debug the environment and simulation output.
# It runs a minimal simulation and fails with the log output so the agent can read it.

using Test
using BallSim
using BallSim.Config
using BallSim.Common
using BallSim.Scenarios

@testset "Debug Agent Tool" begin
    println("--- DEBUG TOOL STARTED ---")

    # Print Env Info
    println("Julia Version: ", VERSION)
    println("Project: ", Base.active_project())
    println("CWD: ", pwd())

    # Setup a minimal simulation
    cfg = Config.SimulationConfig(
        :Spiral, Dict(:N => 5), # Scenario
        1.0, 2,                 # Duration, Dims
        0.1f0, :CCD, Dict(),    # DT, Solver
        :Zero, Dict(),          # Gravity
        :Circle, Dict(:radius => 100.0), # Boundary
        :export, "debug_out", 100, 60, 1, # Output
        "xy", Config.Common.VisualizationConfig()
    )

    try
        # Run 1 step manually
        sys = Common.setup_system(Config.create_scenario(cfg))
        solver = Config.create_solver(cfg)
        boundary = Config.create_boundary(cfg)
        gravity = Config.create_gravity(cfg)

        println("System Initialized: ", sys)

        # Step
        BallSim.Physics.step!(sys, solver, boundary, gravity)
        println("Step 1 Complete. Pos[1]: ", sys.data.pos[1])

        println("--- DEBUG TOOL FINISHED SUCCESSFULLY ---")
        @test true
    catch e
        println("--- DEBUG TOOL FAILED ---")
        showerror(stdout, e, catch_backtrace())
        println()
        @test false
    end
end
