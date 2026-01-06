using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using BallSim
using StaticArrays
using LinearAlgebra
using Printf

# Access internal modules
using BallSim.Common
using BallSim.Physics
using BallSim.Shapes
using BallSim.Scenarios

function run_wall_test()
    println("--- Test 1: Wall Bounce (1D) ---")

    # 1. Setup System: 1 Particle
    sys = BallSystem(1, 2, Float32)
    sys.data.active[1] = true
    sys.data.pos[1] = SVector(0.0f0, 0.0f0)
    sys.data.vel[1] = SVector(10.0f0, 0.0f0) # 10 m/s to the right

    # 2. Boundary: Box of width 2 (x from -1 to 1)
    # Wall at x=1.0.
    boundary = Shapes.Box(2.0f0, 2.0f0)

    # 3. Solver: Restitution 1.0 (Elastic)
    # dt = 0.001 (1ms).
    solver = Physics.CCDSolver(0.001f0, 1.0f0, 1)

    # 4. Zero Gravity
    gravity = (p, v, t) -> SVector(0f0, 0f0)

    # 5. Run
    # Time to hit x=1.0 is 0.1s.
    # We run for 0.2s.
    # At t=0.2, it should be back at 0.0.

    println("  Running for 0.2s...")
    steps = 200 # 0.2 / 0.001

    for _ in 1:steps
        Physics.step!(sys, solver, boundary, gravity)
    end

    pos = sys.data.pos[1]
    vel = sys.data.vel[1]

    println("  Final Pos: $pos (Expected: [0.0, 0.0])")
    println("  Final Vel: $vel (Expected: [-10.0, 0.0])")

    err_pos = norm(pos - SVector(0f0, 0f0))
    if err_pos < 1e-4
        println("  ✅ Position Verified (Error: $err_pos)")
    else
        println("  ❌ Position Mismatch (Error: $err_pos)")
    end
end

function run_gravity_test()
    println("\n--- Test 2: Gravity Drop ---")

    # 1. Setup
    sys = BallSystem(1, 2, Float32)
    sys.data.active[1] = true
    sys.data.pos[1] = SVector(0.0f0, 0.0f0)
    sys.data.vel[1] = SVector(0.0f0, 0.0f0)

    # 2. Boundary: Box large enough in Y.
    # Floor at -5.0. Height 10.
    boundary = Shapes.Box(10.0f0, 10.0f0) # y from -5 to 5.
    # Drop from y=4.0 to y=-5.0?
    # Let's start at y=0. Floor at -5.
    # Drop height h = 5.

    # 3. Gravity g = -10.
    g_val = 10.0f0
    gravity = (p, v, t) -> SVector(0f0, -g_val)

    # 4. Solver
    solver = Physics.CCDSolver(0.001f0, 1.0f0, 1) # 1 sub-step

    # 5. Analytical
    # Time to floor: 5 = 0.5 * 10 * t^2 -> t^2 = 1 -> t = 1.0s.
    # Impact vel: v = -10 * 1 = -10.
    # Bounce: v = +10.
    # Back to top: t = 2.0s.

    println("  Running for 2.0s...")
    steps = 2000

    for _ in 1:steps
        Physics.step!(sys, solver, boundary, gravity)
    end

    pos = sys.data.pos[1]
    vel = sys.data.vel[1]

    println("  Final Pos: $pos (Expected: [0.0, 0.0])")
    println("  Final Vel: $vel (Expected: [0.0, 0.0])")

    err_pos = abs(pos[2] - 0.0f0)
    if err_pos < 0.1 # Euler integration error will be significant over 2000 steps
        println("  ✅ Position Verified (Error: $err_pos)")
    else
        println("  ❌ Position Mismatch (Error: $err_pos)")
    end
end

function run_tunneling_test()
    println("\n--- Test 3: Tunneling Check ---")

    # High speed particle
    sys = BallSystem(1, 2, Float32)
    sys.data.active[1] = true
    sys.data.pos[1] = SVector(0.0f0, 0.0f0)

    # Wall at x=1.0. (Box width 2).
    #boundary = Shapes.Box(2.0f0, 2.0f0)

    println("  Testing Inverted(Circle) tunneling...")

    boundary_inv = Shapes.Inverted(Shapes.Circle(1.0f0))
    # Trap inside circle r=1.

    sys.data.pos[1] = SVector(0.0f0, 0.0f0)

    # dt = 1.0.
    # Velocity to reach x=2.0 (Outside, SDF < 0 for Inverted).
    # v = (2.0, 0).
    sys.data.vel[1] = SVector(2.0f0, 0.0f0)

    solver = Physics.CCDSolver(1.0f0, 1.0f0, 1) # dt=1.0, 1 substep

    gravity = (p, v, t) -> SVector(0f0, 0f0)

    Physics.step!(sys, solver, boundary_inv, gravity)

    pos = sys.data.pos[1]
    println("  Pos after huge step: $pos")

    if norm(pos) > 1.5
        println("  ⚠️ Tunneled! (Expected behavior for discrete collision with thin boundary logic)")
    else
        println("  ✅ Contained (CCD worked?)")
    end

    println("  Testing with Substeps=10...")
    sys.data.pos[1] = SVector(0.0f0, 0.0f0)
    sys.data.vel[1] = SVector(2.0f0, 0.0f0)
    solver_sub = Physics.CCDSolver(1.0f0, 1.0f0, 10)

    Physics.step!(sys, solver_sub, boundary_inv, gravity)
    pos = sys.data.pos[1]
    println("  Pos after huge step (substeps=10): $pos")
     if norm(pos) > 1.5
        println("  ❌ Tunneled with substeps!")
    else
        println("  ✅ Contained with substeps")
    end

end

run_wall_test()
run_gravity_test()
run_tunneling_test()
