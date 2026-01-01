using Test
using StaticArrays
using LinearAlgebra
using Random
using Printf
using Serialization
using BallSim
using BallSim.Common
using BallSim.Shapes
using BallSim.Physics

include("fixtures.jl")
using .TestFixtures

const REGRESSION_DIR = joinpath(@__DIR__, "regression_data")
const UPDATE_FLAG = get(ENV, "UPDATE_REGRESSION", "0") == "1"

struct Fingerprint
    energy_total::Float32
    energy_kinetic::Float32
    particle_count::Int
    center_of_mass::SVector{2, Float32}
    p1_pos::SVector{2, Float32}
    p1_vel::SVector{2, Float32}
    pLast_pos::SVector{2, Float32}
end

function generate_fingerprint(sys)
    mask = sys.data.active
    vels = sys.data.vel[mask]
    pos  = sys.data.pos[mask]
    e_kin = sum(v -> 0.5f0 * norm(v)^2, vels)
    com = sum(pos) / length(pos)
    p1_idx = findfirst(mask); pL_idx = findlast(mask)
    return Fingerprint(e_kin, e_kin, count(mask), com, sys.data.pos[p1_idx], sys.data.vel[p1_idx], sys.data.pos[pL_idx])
end

function load_baseline(filename)
    path = joinpath(REGRESSION_DIR, filename)
    isfile(path) ? deserialize(path) : nothing
end

function save_baseline(filename, data)
    mkpath(REGRESSION_DIR)
    serialize(joinpath(REGRESSION_DIR, filename), data)
    printstyled("    [UPDATED] Baseline saved\n", color=:yellow)
end

function compare_fingerprints(ref::Fingerprint, cur::Fingerprint)
    diffs = []
    check = (name, v_ref, v_cur, tol) -> begin
        delta = norm(v_cur - v_ref)
        rel = delta / (norm(v_ref) + 1e-9)
        if rel > tol push!(diffs, (name, v_ref, v_cur, delta, rel)) end
    end
    check("Energy Total", ref.energy_total, cur.energy_total, 1e-5)
    check("Center of Mass", ref.center_of_mass, cur.center_of_mass, 1e-4)
    check("P1 Position", ref.p1_pos, cur.p1_pos, 1e-4)
    return diffs
end

@testset "Regression Testing" begin
    TestFixtures.print_header("Physics Regression Baseline")
    scenario_name = "pinball_chaos_ccd.jld"
    Random.seed!(12345)
    sys = Common.BallSystem(50, 2, Float32)
    for i in 1:50
        sys.data.active[i] = true
        sys.data.pos[i] = SVector(-0.8f0 + i*0.02f0, 0.0f0 + i*0.01f0)
        sys.data.vel[i] = SVector(5.0f0, -2.0f0)
    end

    solver = Physics.CCDSolver(0.01f0, 1.0f0, 8)
    boundary = Shapes.Box(2.0f0, 2.0f0)
    gravity = Common.Gravity2D

    for _ in 1:200 Physics.step!(sys, solver, boundary, gravity) end

    current_fp = generate_fingerprint(sys)
    reference_fp = load_baseline(scenario_name)

    if reference_fp === nothing
        printstyled("    [NEW] No baseline found. Creating new.\n", color=:cyan)
        save_baseline(scenario_name, current_fp)
        @test true
    elseif UPDATE_FLAG
        printstyled("    [FORCED UPDATE] Overwriting baseline.\n", color=:yellow)
        save_baseline(scenario_name, current_fp)
        @test true
    else
        diffs = compare_fingerprints(reference_fp, current_fp)
        if isempty(diffs)
            printstyled("    [MATCH] Simulation matches golden master.\n", color=:green)
            @test true
        else
            println("\n⚠️  REGRESSION DETECTED!")
            for (name, r, c, d, rel) in diffs
                @printf "%-15s | Delta: %.1e\n" name d
            end
            @test isempty(diffs)
        end
    end
end
