module Config

using JSON3
using StaticArrays
using ..Common
using ..Shapes
using ..Fields
using ..Physics
using ..Scenarios

struct SimulationConfig
    # Scenario
    scenario_type::Symbol
    scenario_params::Dict{Symbol, Any}
    
    # Simulation meta
    duration::Float64
    dimensions::Int
    
    # Physics
    dt::Float32
    solver::Symbol
    solver_params::Dict{Symbol, Any}
    
    gravity_type::Symbol
    gravity_params::Dict{Symbol, Any}
    
    boundary_type::Symbol
    boundary_params::Dict{Symbol, Any}
    
    # Output
    mode::Symbol       
    output_file::String
    res::Int
    fps::Int
end

# ==============================================================================
# VALIDATION HELPERS
# ==============================================================================

function validate_positive(val, name)
    if val <= 0
        error("Config Error: '$name' must be positive. Got: $val")
    end
    return val
end

function validate_choice(val, choices, name)
    if !(val in choices)
        error("Config Error: '$name' must be one of $choices. Got: $val")
    end
    return val
end

function validate_boundary_params(type, params)
    if type in (:Circle, :InvertedCircle)
        if !haskey(params, :radius) error("Config Error: Boundary '$type' requires 'radius'.") end
        if params[:radius] <= 0 error("Config Error: 'radius' must be positive.") end
    elseif type == :Box
        if !haskey(params, :width) || !haskey(params, :height) error("Config Error: Box requires 'width' and 'height'.") end
        if params[:width] <= 0 || params[:height] <= 0 error("Config Error: Box dims must be positive.") end
    elseif type == :Ellipsoid
        if !haskey(params, :rx) || !haskey(params, :ry) error("Config Error: Ellipsoid requires 'rx' and 'ry'.") end
        if params[:rx] <= 0 || params[:ry] <= 0 error("Config Error: Ellipsoid radii must be positive.") end
    end
end

function validate_gravity_params(type, params, dims)
    if type == :Uniform
        if !haskey(params, :vector) error("Config Error: Uniform gravity requires 'vector'.") end
        if length(params[:vector]) != dims error("Config Error: Gravity vector must have $dims components.") end
    elseif type == :Central
        if !haskey(params, :strength) error("Config Error: Central gravity requires 'strength'.") end
    end
end

# ==============================================================================
# LOADER
# ==============================================================================

function load_config(path::String)
    if !isfile(path) error("Config Error: File not found at $path") end
    json_string = read(path, String)
    data = try JSON3.read(json_string) catch e error("Invalid JSON") end
    
    # 1. Simulation / Scenario
    if !haskey(data, :simulation) error("Missing 'simulation' block") end
    sim = data.simulation
    
    scen_type = Symbol(get(sim, :type, "Spiral"))
    scen_params = Dict{Symbol, Any}(k => v for (k, v) in get(sim, :params, Dict()))
    
    # Backward compat for top-level N
    if haskey(sim, :N)
        scen_params[:N] = validate_positive(sim.N, "simulation.N")
    end
    
    duration = validate_positive(Float64(get(sim, :duration, 10.0)), "simulation.duration")
    dimensions = validate_choice(Int(get(sim, :dimensions, 2)), [2, 3], "simulation.dimensions")

    # 2. Physics
    if !haskey(data, :physics) error("Missing 'physics' block") end
    phys = data.physics
    dt = validate_positive(Float32(get(phys, :dt, 0.002)), "physics.dt")
    solver = validate_choice(Symbol(get(phys, :solver, "CCD")), [:CCD], "physics.solver")
    
    solver_params = Dict{Symbol, Any}(k => v for (k, v) in get(phys, :solver_params, Dict()))

    # Gravity
    if !haskey(phys, :gravity) error("Missing 'physics.gravity'") end
    grav = phys.gravity
    grav_type = validate_choice(Symbol(get(grav, :type, "Zero")), [:Uniform, :Central, :Zero], "gravity.type")
    grav_params = Dict{Symbol, Any}(k => v for (k, v) in get(grav, :params, Dict()))
    validate_gravity_params(grav_type, grav_params, dimensions)
    
    # Boundary
    if !haskey(phys, :boundary) error("Missing 'physics.boundary'") end
    bound = phys.boundary
    bound_type = validate_choice(Symbol(get(bound, :type, "Circle")), [:Circle, :Box, :Ellipsoid, :InvertedCircle], "boundary.type")
    bound_params = Dict{Symbol, Any}(k => v for (k, v) in get(bound, :params, Dict()))
    validate_boundary_params(bound_type, bound_params)
    
    # 3. Output
    if !haskey(data, :output) error("Missing 'output' block") end
    out = data.output
    mode = validate_choice(Symbol(get(out, :mode, "interactive")), [:interactive, :render, :export], "output.mode")
    output_file = get(out, :filename, "sandbox/output")
    res = validate_positive(get(out, :res, 800), "output.res")
    fps = validate_positive(get(out, :fps, 60), "output.fps")

    return SimulationConfig(
        scen_type, scen_params, duration, dimensions,
        dt, solver, solver_params,
        grav_type, grav_params,
        bound_type, bound_params,
        mode, output_file, res, fps
    )
end

# --- Factories ---

function create_scenario(cfg::SimulationConfig)
    t = cfg.scenario_type
    p = cfg.scenario_params
    
    if t == :Spiral
        N = get(p, :N, 1000)
        m_min = get(p, :mass_min, 1.0)
        m_max = get(p, :mass_max, 1.0)
        if cfg.dimensions == 2
            return Scenarios.SpiralScenario(N=Int(N), mass_min=Float32(m_min), mass_max=Float32(m_max))
        elseif cfg.dimensions == 3
            return Scenarios.SpiralScenario3D(N=Int(N), mass_min=Float32(m_min), mass_max=Float32(m_max))
        end
    else
        error("Unknown Scenario Type: $t")
    end
end

function create_solver(cfg::SimulationConfig)
    if cfg.solver == :CCD
        rest = Float32(get(cfg.solver_params, :restitution, 1.0))
        sub  = Int(get(cfg.solver_params, :substeps, 8))
        return Physics.CCDSolver(cfg.dt, rest, sub)
    else
        error("Unknown Solver: $(cfg.solver)")
    end
end

function create_boundary(cfg::SimulationConfig)
    t = cfg.boundary_type
    p = cfg.boundary_params

    if cfg.dimensions == 3
        if t == :Circle || t == :Circle3D
            return Shapes.Circle3D(Float32(p[:radius]))
        elseif t == :InvertedCircle
             return Shapes.Inverted(Shapes.Circle3D(Float32(p[:radius])))
        else
            error("Boundary '$t' not supported in 3D yet (only Circle/Circle3D).")
        end
    else # 2D
        if t == :Circle
            return Shapes.Circle(Float32(p[:radius]))
        elseif t == :Box
            return Shapes.Box(Float32(p[:width]), Float32(p[:height]))
        elseif t == :Ellipsoid
            return Shapes.Ellipsoid(Float32(p[:rx]), Float32(p[:ry]))
        elseif t == :InvertedCircle
            return Shapes.Inverted(Shapes.Circle(Float32(p[:radius])))
        else
            error("Unknown Boundary Type: $t")
        end
    end
end

function create_gravity(cfg::SimulationConfig)
    t = cfg.gravity_type
    p = cfg.gravity_params

    if t == :Uniform
        v = p[:vector]
        if cfg.dimensions == 2
            return Fields.UniformField(SVector(Float32(v[1]), Float32(v[2])))
        elseif cfg.dimensions == 3
            return Fields.UniformField(SVector(Float32(v[1]), Float32(v[2]), Float32(v[3])))
        end
    elseif t == :Central
        c = get(p, :center, zeros(Float32, cfg.dimensions))
        if cfg.dimensions == 2
            pos = SVector(Float32(c[1]), Float32(c[2]))
        elseif cfg.dimensions == 3
            pos = SVector(Float32(c[1]), Float32(c[2]), Float32(c[3]))
        end
        return Fields.CentralField(
            pos,
            Float32(p[:strength]),
            mode = Symbol(get(p, :mode, "attractor"))
        )
    elseif t == :Zero
        if cfg.dimensions == 2
            return (p, v, m, t) -> SVector(0f0, 0f0)
        elseif cfg.dimensions == 3
            return (p, v, m, t) -> SVector(0f0, 0f0, 0f0)
        end
    else
        error("Unknown Gravity Type: $t")
    end
end

function create_mode(cfg::SimulationConfig)
    if cfg.mode == :interactive
        return Common.InteractiveMode(res=cfg.res, fps=cfg.fps)
    elseif cfg.mode == :render
        mkpath(dirname(cfg.output_file))
        fname = endswith(cfg.output_file, ".mp4") ? cfg.output_file : "$(cfg.output_file).mp4"
        return Common.RenderMode(fname, fps=cfg.fps, res=cfg.res)
    elseif cfg.mode == :export
        mkpath(dirname(cfg.output_file))
        fname = endswith(cfg.output_file, ".h5") ? cfg.output_file : "$(cfg.output_file).h5"
        return Common.ExportMode(fname, interval=10)
    else
        error("Unknown Mode: $(cfg.mode)")
    end
end

end