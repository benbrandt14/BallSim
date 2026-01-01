module TestFixtures

using LinearAlgebra
using StaticArrays
using Statistics
using Printf
using Test

using BallSim
using BallSim.Common
using BallSim.Physics

# ==============================================================================
# 1. VISUALIZATION
# ==============================================================================

function print_header(title)
    println("\n" * "="^60)
    println("DIAGNOSTIC: $title")
    println("="^60)
end

function print_sdf_slice(boundary, limits=1.2, res=20)
    println("\n--- SDF Slice (.: Inside, #: Surface, Space: Outside) ---")
    xs = range(-limits, limits, length=res*2)
    ys = range(limits, -limits, length=res)
    for y in ys
        line = ""
        for x in xs
            p = SVector(Float32(x), Float32(y))
            d = Common.sdf(boundary, p, 0.0f0)
            if abs(d) < 0.05
                line *= "##"
            elseif d < 0
                line *= ".."
            else
                line *= "  "
            end
        end
        println(line)
    end
end

function print_vector_field(boundary, limits=1.2, res=10)
    println("\n--- Gradient Vector Field ---")
    xs = range(-limits, limits, length=res)
    ys = range(limits, -limits, length=res)
    for y in ys
        line = ""
        for x in xs
            p = SVector(Float32(x), Float32(y))
            n = Common.normal(boundary, p, 0.0f0)
            angle = atan(n[2], n[1])
            sector = mod(round(Int, 8 * angle / (2π)) + 8, 8)
            char = if sector == 0 "-> " elseif sector == 1 "/^ " elseif sector == 2 "^| " elseif sector == 3 "^\\ " elseif sector == 4 "<- " elseif sector == 5 "\\v " elseif sector == 6 "v| " elseif sector == 7 "v/ " else "?? " end
            line *= char
        end
        println(line)
    end
end

function check_gradients(boundary, points; tolerance=0.99)
    println("\n--- Gradient Consistency Check ---")
    all_pass = true
    for p in points
        n_analytic = Common.normal(boundary, p, 0.0f0)
        ϵ = 1f-4
        d_c = Common.sdf(boundary, p, 0.0f0)
        d_x = Common.sdf(boundary, p + SVector(ϵ, 0), 0.0f0)
        d_y = Common.sdf(boundary, p + SVector(0, ϵ), 0.0f0)
        d_xm = Common.sdf(boundary, p - SVector(ϵ, 0), 0.0f0)
        d_ym = Common.sdf(boundary, p - SVector(0, ϵ), 0.0f0)
        n_num = normalize(SVector((d_x - d_xm)/(2ϵ), (d_y - d_ym)/(2ϵ)))

        alignment = dot(n_analytic, n_num)
        if alignment < tolerance
            @printf "[FAIL] At (%.2f, %.2f): Alignment %.4f\n" p[1] p[2] alignment
            all_pass = false
        end
    end
    if all_pass println("[PASS] All sampled gradients align with numerical derivatives.") end
    return all_pass
end

# ==============================================================================
# 2. BENCHMARKING LOGIC
# ==============================================================================

struct SimMetrics
    name::String
    energy_drift::Float32
    escape_rate::Float32
    steps_per_sec::Float64
    max_velocity::Float32
    passed::Bool
end

struct Scenario
    name::String
    duration::Float64
    sys_builder::Function
    boundary::Common.AbstractBoundary
    gravity::Function
end

function run_scenario(solver_name, solver, scenario::Scenario; verbose=false)
    sys = scenario.sys_builder()
    mask = sys.data.active
    E_init = sum(v -> 0.5f0 * norm(v)^2, sys.data.vel[mask])
    N_init = count(mask)

    steps = ceil(Int, scenario.duration / solver.dt)
    t0 = time_ns()
    max_vel = 0.0f0

    for step_i in 1:steps
        Physics.step!(sys, solver, scenario.boundary, scenario.gravity)
        if step_i % 100 == 0
            active_vels = sys.data.vel[sys.data.active]
            if !isempty(active_vels)
                max_vel = max(max_vel, maximum(norm.(active_vels)))
            end
        end
    end
    t_total = (time_ns() - t0) / 1e9

    mask_final = sys.data.active
    E_final = isempty(mask_final) ? 0.0f0 : sum(v -> 0.5f0 * norm(v)^2, sys.data.vel[mask_final])
    N_final = count(mask_final)

    drift = (E_final - E_init) / (E_init + 1f-9)
    drift_rate = drift / scenario.duration
    escape_rate = ((N_init - N_final) / N_init) / scenario.duration
    throughput = steps / t_total

    passed = abs(drift_rate) < 0.05 && escape_rate == 0.0

    return SimMetrics(solver_name, drift_rate, escape_rate, throughput, max_vel, passed)
end

function compare_solvers(scenario::Scenario, solvers::Dict)
    println("\nBENCHMARK: $(scenario.name)")
    println("-"^80)
    @printf "%-18s | %-12s | %-12s | %-12s | %s\n" "SOLVER" "DRIFT/s" "ESCAPES/s" "STEPS/s" "STATUS"
    println("-"^80)

    results = []
    for name in sort(collect(keys(solvers)))
        solver = solvers[name]
        m = run_scenario(name, solver, scenario)
        push!(results, m)
        status = m.passed ? "[PASS]" : "[FAIL]"
        drift_str = @sprintf("%+.2f%%", m.energy_drift * 100)
        esc_str   = @sprintf("%.2f%%", m.escape_rate * 100)
        perf_str  = @sprintf("%.1e", m.steps_per_sec)
        @printf "%-18s | %-12s | %-12s | %-12s | %s\n" name drift_str esc_str perf_str status
    end
    println("-"^80)
    return results
end

end
