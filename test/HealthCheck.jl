module HealthCheck
using LinearAlgebra
using StaticArrays
using Statistics
using Printf

using BallSim.Common
using BallSim.Physics

struct SimMetrics
    name::String
    energy_drift::Float32   # %/sec
    escape_rate::Float32    # %/sec
    steps_per_sec::Float64
    max_velocity::Float32
    passed::Bool
end

# A reusable scenario definition
struct Scenario
    name::String
    duration::Float64
    sys_builder::Function
    boundary::Common.AbstractBoundary
    gravity::Function
end

function run_scenario(solver_name, solver, scenario::Scenario)
    # 1. Setup System
    sys = scenario.sys_builder()

    # Snapshot Initial State
    mask = sys.data.active
    # Use sum generator to avoid allocations
    E_init = sum(v -> 0.5f0 * norm(v)^2, sys.data.vel[mask])
    N_init = count(mask)

    steps = ceil(Int, scenario.duration / solver.dt)
    t_elapsed = 0.0
    max_vel = 0.0f0

    # 2. Run Loop
    t0 = time_ns()
    # FIX: Changed '_' to 'step_i' so we can use it in the if-statement
    for step_i in 1:steps
        Physics.step!(sys, solver, scenario.boundary, scenario.gravity)

        # Sampling (every 100 steps to save overhead)
        if step_i % 100 == 0
            # Quick check on active particles only
            active_vels = sys.data.vel[sys.data.active]
            if !isempty(active_vels)
                v = maximum(norm.(active_vels))
                max_vel = max(max_vel, v)
            end
        end
    end
    t_total = (time_ns() - t0) / 1e9

    # 3. Analyze
    final_mask = sys.data.active
    if count(final_mask) > 0
        E_final = sum(v -> 0.5f0 * norm(v)^2, sys.data.vel[final_mask])
    else
        E_final = 0.0f0
    end
    N_final = count(final_mask)

    # Avoid divide by zero if E_init is 0
    drift = (E_final - E_init) / (E_init + 1e-9)
    drift_rate = drift / scenario.duration
    escape_rate = ((N_init - N_final) / N_init) / scenario.duration
    throughput = steps / t_total

    # Criteria (Adjust tolerances as needed)
    passed = abs(drift_rate) < 0.05 && escape_rate == 0.0

    return SimMetrics(solver_name, drift_rate, escape_rate, throughput, max_vel, passed)
end

function compare_solvers(scenario::Scenario, solvers::Dict)
    println("\n📊 BENCHMARK: $(scenario.name)")
    println("="^75)
    @printf "%-15s | %-12s | %-12s | %-12s | %s\n" "SOLVER" "DRIFT/s" "ESCAPES/s" "STEPS/s" "STATUS"
    println("-"^75)

    results = []

    # Sort keys for consistent output order
    for name in sort(collect(keys(solvers)))
        solver = solvers[name]
        # Run
        m = run_scenario(name, solver, scenario)
        push!(results, m)

        # Print Row
        status = m.passed ? "✅ PASS" : "❌ FAIL"
        drift_str = @sprintf("%+.2f%%", m.energy_drift * 100)
        esc_str = @sprintf("%.2f%%", m.escape_rate * 100)
        perf_str = @sprintf("%.1e", m.steps_per_sec)

        @printf "%-15s | %-12s | %-12s | %-12s | %s\n" name drift_str esc_str perf_str status
    end
    println("="^75)
    return results
end

end
