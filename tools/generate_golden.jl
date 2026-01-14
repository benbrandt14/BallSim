using BallSim
using StaticArrays
using SHA
using Printf

# Deterministic Setup
function run_deterministic_simulation()
    # 1. Setup
    # Fixed seed is not enough if we rely on global RNG, but we initialize explicitly.
    N = 100
    D = 2
    T = Float32
    sys = BallSim.Common.BallSystem(N, D, T)

    # Initialize positions in a grid
    k = 0
    for i in 1:10
        for j in 1:10
            k += 1
            x = (i - 5.5f0) * 1.0f0
            y = (j - 5.5f0) * 1.0f0
            sys.data.pos[k] = SVector(x, y)
            sys.data.vel[k] = SVector(-y, x) # Rotation
            sys.data.active[k] = true
            sys.data.mass[k] = 1.0f0
        end
    end

    # 2. Physics Config
    dt = 0.01f0
    solver = BallSim.Physics.CCDSolver(dt, 0.8f0, 4)
    boundary = BallSim.Shapes.Circle(10.0f0)
    gravity = (p, v, m, t) -> SVector(0.0f0, -1.0f0) # Slight gravity

    # 3. Run for N steps
    n_steps = 500
    for _ in 1:n_steps
        BallSim.Physics.step!(sys, solver, boundary, gravity)
    end

    return sys
end

function compute_hash(sys)
    # Hash the position array
    # Convert to bytes
    buffer = IOBuffer()
    for p in sys.data.pos
        # Write individual components to avoid padding issues or struct alignment noise
        write(buffer, p[1])
        write(buffer, p[2])
    end
    return bytes2hex(sha256(take!(buffer)))
end

sys = run_deterministic_simulation()
h = compute_hash(sys)
println("Golden Hash: ", h)
