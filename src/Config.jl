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

function validate_gravity_params(type, params)
    if type == :Uniform
        if !haskey(params, :vector) error("Config Error: Uniform gravity requires 'vector' [x, y].") end
        if length(params[:vector]) != 2 error("Config Error: Gravity vector must have 2 components.") end
    elseif type == :Central
        if !haskey(params, :strength) error("Config Error: Central gravity requires 'strength'.") end
    end
end

# ==============================================================================
# LOADER
# ==============================================================================

function recursive_merge!(base::AbstractDict, overrides::AbstractDict)
    for (k, v) in overrides
        if haskey(base, k) && base[k] isa AbstractDict && v isa AbstractDict
            recursive_merge!(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end

function load_config(path::String, overrides::Dict{String, Any}=Dict{String, Any}())
    if !isfile(path) error("Config Error: File not found at $path") end
    json_string = read(path, String)
    data = try JSON3.read(json_string) catch e error("Invalid JSON") end
    
    # Convert JSON3 object to Mutable Dict for merging
    data_dict = Dict{String, Any}()
    # A simple way to convert deeply is tricky with JSON3 without extra steps,
    # but we can do a round trip or manual conversion.
    # For simplicity, we assume shallow conversion is enough for top levels if we access them as Symbols?
    # No, JSON3 uses Symbols by default for keys if not specified.
    # Let's iterate and convert to String keys to match overrides which are String keys.

    # Helper to convert JSON3 Object to Dict{String, Any}
    function to_dict(obj)
        if obj isa JSON3.Object
            return Dict{String, Any}(string(k) => to_dict(v) for (k, v) in obj)
        elseif obj isa AbstractArray
            return [to_dict(x) for x in obj]
        else
            return obj
        end
    end

    data_dict = to_dict(data)

    # Merge overrides
    if !isempty(overrides)
        recursive_merge!(data_dict, overrides)
    end

    # Helper to access nested Dict with String keys
    function get_nested(d, keys...)
        curr = d
        for k in keys
            if !haskey(curr, k) return nothing end
            curr = curr[k]
        end
        return curr
    end

    # 1. Simulation / Scenario
    if !haskey(data_dict, "simulation") error("Missing 'simulation' block") end
    sim = data_dict["simulation"]
    
    scen_type = Symbol(get(sim, "type", "Spiral"))
    scen_params = Dict{Symbol, Any}(Symbol(k) => v for (k, v) in get(sim, "params", Dict()))
    
    # Backward compat for top-level N
    if haskey(sim, "N")
        scen_params[:N] = validate_positive(sim["N"], "simulation.N")
    end
    
    duration = validate_positive(Float64(get(sim, "duration", 10.0)), "simulation.duration")

    # 2. Physics
    if !haskey(data_dict, "physics") error("Missing 'physics' block") end
    phys = data_dict["physics"]
    dt = validate_positive(Float32(get(phys, "dt", 0.002)), "physics.dt")
    solver = validate_choice(Symbol(get(phys, "solver", "CCD")), [:CCD], "physics.solver")
    
    solver_params = Dict{Symbol, Any}(Symbol(k) => v for (k, v) in get(phys, "solver_params", Dict()))

    # Gravity
    if !haskey(phys, "gravity") error("Missing 'physics.gravity'") end
    grav = phys["gravity"]
    grav_type = validate_choice(Symbol(get(grav, "type", "Zero")), [:Uniform, :Central, :Zero], "gravity.type")
    grav_params = Dict{Symbol, Any}(Symbol(k) => v for (k, v) in get(grav, "params", Dict()))
    validate_gravity_params(grav_type, grav_params)
    
    # Boundary
    if !haskey(phys, "boundary") error("Missing 'physics.boundary'") end
    bound = phys["boundary"]
    bound_type = validate_choice(Symbol(get(bound, "type", "Circle")), [:Circle, :Box, :Ellipsoid, :InvertedCircle], "boundary.type")
    bound_params = Dict{Symbol, Any}(Symbol(k) => v for (k, v) in get(bound, "params", Dict()))
    validate_boundary_params(bound_type, bound_params)
    
    # 3. Output
    if !haskey(data_dict, "output") error("Missing 'output' block") end
    out = data_dict["output"]
    mode = validate_choice(Symbol(get(out, "mode", "interactive")), [:interactive, :render, :export], "output.mode")
    output_file = get(out, "filename", "sandbox/output")
    res = validate_positive(get(out, "res", 800), "output.res")
    fps = validate_positive(get(out, "fps", 60), "output.fps")

    return SimulationConfig(
        scen_type, scen_params, duration,
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
        return Scenarios.SpiralScenario(N=Int(N))
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

function create_gravity(cfg::SimulationConfig)
    t = cfg.gravity_type
    p = cfg.gravity_params
    if t == :Uniform
        v = p[:vector]
        return Fields.UniformField(SVector(Float32(v[1]), Float32(v[2])))
    elseif t == :Central
        c = get(p, :center, [0.0, 0.0])
        return Fields.CentralField(
            SVector(Float32(c[1]), Float32(c[2])),
            Float32(p[:strength]),
            mode = Symbol(get(p, :mode, "attractor"))
        )
    elseif t == :Zero
        return (p, v, t) -> SVector(0f0, 0f0)
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