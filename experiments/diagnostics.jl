include("../src/Common.jl")
include("../src/Shapes.jl")
include("../src/Physics.jl")

using .Common
using .Shapes
using .Physics

using GLMakie
using StaticArrays
using LinearAlgebra
using Printf
using Statistics

# ==============================================================================
# 1. HELPER TYPES
# ==============================================================================
struct Floor <: Common.AbstractBoundary end
Common.sdf(::Floor, p, t) = -p[2]
Common.normal(::Floor, p, t) = SVector(0.0f0, -1.0f0)

struct VerticalWall <: Common.AbstractBoundary
    x::Float32
end
Common.sdf(w::VerticalWall, p, t) = p[1] - w.x
Common.normal(::VerticalWall, p, t) = SVector(1.0f0, 0.0f0)

# ==============================================================================
# 2. ANALYTICAL MATH
# ==============================================================================
function analytical_bounce(t_total, y0, v0, g, cor)
    t = t_total
    y = y0
    v = v0
    max_bounces = 100
    for _ in 1:max_bounces
        discriminant = v^2 + 2 * g * y
        if discriminant < 0
            break
        end
        t_impact = (v + sqrt(discriminant)) / g
        if t < t_impact
            return y + v * t - 0.5f0 * g * t^2
        else
            t -= t_impact
            v = -(v - g * t_impact) * cor
            y = 0.0f0
            if abs(v) < 0.1
                return 0.0f0
            end
        end
    end
    return 0.0f0
end

# ==============================================================================
# 3. DIAGNOSTICS
# ==============================================================================

function diagnose_bounce(solver)
    println(">> Running Bounce Accuracy...")
    sys = Common.BallSystem(1, 2, Float32)
    sys.data.active[1] = true
    sys.data.pos[1] = SVector(0.0f0, 2.0f0)
    sys.data.vel[1] = SVector(0.0f0, 0.0f0)
    g_val = 10.0f0
    cor = 0.9f0

    times = Float32[]
    y_sim = Float32[]
    y_ana = Float32[]
    for i in 1:400
        Physics.step!(sys, solver, Floor(), (p, v, t) -> SVector(0.0f0, -g_val))
        push!(times, sys.t)
        push!(y_sim, sys.data.pos[1][2])
        push!(y_ana, analytical_bounce(sys.t, 2.0f0, 0.0f0, g_val, cor))
    end

    fig = Figure(size=(800, 800))
    ax1 = Axis(fig[1, 1], title="Trajectory Comparison", ylabel="Height (m)")
    ax2 = Axis(fig[2, 1], title="Error Residuals", xlabel="Time (s)", ylabel="Delta (m)")

    lines!(ax1, times, y_ana, color=:black, linewidth=4, label="Analytical")
    lines!(ax1, times, y_sim, color=:red, linewidth=2, label="Simulated")
    axislegend(ax1)
    lines!(ax2, times, y_sim .- y_ana, color=:blue)
    hlines!(ax2, [0.0], color=:black)
    display(fig)
end

function diagnose_microscope(solver)
    println(">> Running Wall Impact Microscope...")
    fig = Figure(size=(800, 800))
    ax = Axis(fig[1, 1], title="Reflection Angles (15° Steps)", aspect=DataAspect(), xlabel="X (Wall at 1.0)", ylabel="Y")
    vlines!(ax, [1.0], color=:black, linewidth=5, label="Wall")

    angles = 0:15:75
    speed = 10.0f0
    for (i, ang_deg) in enumerate(angles)
        ang = deg2rad(ang_deg)
        vx = speed * cos(ang)
        vy = speed * sin(ang)
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        sys.data.pos[1] = SVector(1.0f0 - (vx * 0.1f0), -(vy * 0.1f0))
        sys.data.vel[1] = SVector(vx, vy)

        path_x = Float32[]
        path_y = Float32[]
        push!(path_x, sys.data.pos[1][1])
        push!(path_y, sys.data.pos[1][2])
        for _ in 1:25
            Physics.step!(sys, solver, VerticalWall(1.0f0), (p, v, t) -> SVector(0.0f0, 0.0f0))
            push!(path_x, sys.data.pos[1][1])
            push!(path_y, sys.data.pos[1][2])
        end

        split_idx = argmax(path_x)
        lines!(ax, path_x[1:split_idx], path_y[1:split_idx], color=:blue, linewidth=2)
        lines!(ax, path_x[split_idx:end], path_y[split_idx:end], color=:red, linewidth=2)
        text!(ax, path_x[1], path_y[1], text="$(ang_deg)°", align=(:right, :center))
    end
    display(fig)
end

function diagnose_penetration(solver)
    println(">> Running Penetration Stress Test...")
    velocities = [10.0f0, 100.0f0, 500.0f0, 1000.0f0]

    fig = Figure(size=(1000, 800))
    ax = Axis(fig[1, 1], title="Wall Penetration Check (0° Incidence)", xlabel="Simulation Step", ylabel="Dist to Wall (Negative = Penetration)")
    hlines!(ax, [0.0], color=:black, linewidth=2, linestyle=:dash, label="Wall Surface")

    for (i, v) in enumerate(velocities)
        sys = Common.BallSystem(1, 2, Float32)
        sys.data.active[1] = true
        dist_start = v * solver.dt * 5.0f0
        sys.data.pos[1] = SVector(-dist_start, 0.0f0)
        sys.data.vel[1] = SVector(v, 0.0f0)

        wall = VerticalWall(0.0f0)
        dists = Float32[]

        for _ in 1:15
            Physics.step!(sys, solver, wall, (p, v, t) -> SVector(0.0f0, 0.0f0))
            push!(dists, sys.data.pos[1][1])
        end
        lines!(ax, 1:15, dists, label="v=$(Int(v)) m/s", linewidth=2)
        scatter!(ax, 1:15, dists, markersize=8)
    end

    hspan!(ax, 0.0, 1000.0, color=(:red, 0.1), label="Penetration Zone")
    axislegend(ax, position=:lt)
    text!(ax, 0.5, 0.95, text="Note: Points inside Red Zone mean failure", align=(:center, :top), space=:relative)
    display(fig)
end

function diagnose_energy_distribution(solver)
    println(">> Running Energy Distribution Monitor...")

    N = 200
    sys = Common.BallSystem(N, 2, Float32)
    # Initialize with varied energies
    for i in 1:N
        sys.data.active[i] = true
        sys.data.pos[i] = SVector((rand(Float32) - 0.5f0) * 1.8f0, (rand(Float32) - 0.5f0) * 1.8f0)
        sys.data.vel[i] = SVector(randn(Float32) * 2, randn(Float32) * 2)
    end

    g_val = 10.0f0
    boundary = Shapes.Box(2.0f0, 2.0f0) # Floor is at y = -1.0

    steps = 400

    # Storage for totals
    t_hist = Float32[]
    E_tot = Float32[]

    # Storage for Distribution (Heatmap)
    n_bins = 50
    max_e = 20.0f0
    heatmap_matrix = zeros(Float32, n_bins, steps)

    for s in 1:steps
        Physics.step!(sys, solver, boundary, (p, v, t) -> SVector(0.0f0, -g_val))

        # 1. Total
        ke = sum(v -> 0.5f0 * norm(v)^2, sys.data.vel)
        pe = sum(p -> g_val * (p[2] + 1.0f0), sys.data.pos)
        push!(t_hist, sys.t)
        push!(E_tot, ke + pe)

        # 2. Distribution
        for i in 1:N
            if !sys.data.active[i]
                continue
            end
            p = sys.data.pos[i]
            v = sys.data.vel[i]

            # Potential Energy = m*g*h. h = y - (-1.0) = y + 1.0.
            e = 0.5f0 * norm(v)^2 + g_val * (p[2] + 1.0f0)

            # Map energy to bin
            bin_idx = floor(Int, (e / max_e) * n_bins) + 1

            # FIX: Clamp bin index to be safe (min 1, max n_bins)
            # This handles small negative epsilons or huge energy spikes
            bin_idx = clamp(bin_idx, 1, n_bins)

            heatmap_matrix[bin_idx, s] += 1
        end
    end

    fig = Figure(size=(1000, 900))

    ax1 = Axis(fig[1, 1], title="Total System Energy", ylabel="Joules")
    lines!(ax1, t_hist, E_tot, color=:black, linewidth=3)

    ax2 = Axis(fig[2, 1], title="Energy Distribution over Time", xlabel="Time Step", ylabel="Energy (J)")
    heatmap!(ax2, 1:steps, range(0, max_e, length=n_bins), heatmap_matrix, colormap=:viridis)

    display(fig)
end

function diagnose_performance(solver)
    println(">> Running Performance Profiling...")
    counts = [10, 100, 1_000, 10_000, 100_000]
    times_ms = Float64[]
    boundary = Shapes.Box(10.0f0, 10.0f0)
    gravity = (p, v, t) -> SVector(0.0f0, -10.0f0)

    for N in counts
        print("    N=$N ... ")
        sys = Common.BallSystem(N, 2, Float32)
        sys.data.active .= true
        Physics.step!(sys, solver, boundary, gravity) # Warmup
        t0 = time_ns()
        for _ in 1:10
            Physics.step!(sys, solver, boundary, gravity)
        end
        avg_ms = ((time_ns() - t0) / 1e6) / 10.0
        push!(times_ms, avg_ms)
        println("$(round(avg_ms, digits=2)) ms")
    end

    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], title="Solver Scaling", xlabel="Count", ylabel="ms/frame", xscale=log10, yscale=log10)
    scatterlines!(ax, counts, times_ms, color=:purple, linewidth=3)
    ref_n = counts .* (times_ms[1] / counts[1])
    lines!(ax, counts, ref_n, color=:grey, linestyle=:dash, label="Linear O(N)")
    axislegend(ax)
    display(fig)
end

# ==============================================================================
# 4. INTERACTIVE MENU
# ==============================================================================

function get_user_solver()
    println("\n=== Select Solver ===")
    println("1. Discrete Solver (Fast, Lower Quality)")
    println("2. CCD Solver (Precise, Slower)")
    print("> ")
    choice = readline()
    if strip(choice) == "1"
        return Physics.DiscreteSolver(0.01f0, 5, 0.9f0)
    else
        return Physics.CCDSolver(0.01f0, 0.9f0, 8)
    end
end

function main()
    solver = get_user_solver()
    println("\nActive Solver: $(typeof(solver))")

    while true
        println("\n=== Diagnostic Menu ===")
        println("1. Bounce Accuracy")
        println("2. Wall Microscope (Angle)")
        println("3. Wall Penetration (Velocity)")
        println("4. Energy Distribution")
        println("5. Performance Profile")
        println("q. Quit")
        print("> ")

        choice = strip(readline())

        if choice == "1"
            diagnose_bounce(solver)
        elseif choice == "2"
            diagnose_microscope(solver)
        elseif choice == "3"
            diagnose_penetration(solver)
        elseif choice == "4"
            diagnose_energy_distribution(solver)
        elseif choice == "5"
            diagnose_performance(solver)
        elseif choice == "q"
            break
        end
    end
end

main()
