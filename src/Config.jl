module Config

using JSON3
using StaticArrays
using ..Common
using ..Shapes
using ..Fields
using ..Physics
using ..Scenarios

struct SimulationConfig
    N::Int
    duration::Float64
    mode::Symbol       
    output_file::String
    dt::Float32
    solver::Symbol     
    gravity_type::Symbol
    gravity_params::Dict{Symbol, Any}
    boundary_type::Symbol
    boundary_params::Dict{Symbol, Any}
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
        if !haskey(params, :radius) error("Config Error: Boundary '$type' requires 'radius' parameter.") end
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
# FACTORY FUNCTIONS
# ==============================================================================

function load_config(path::String)
    if !isfile(path)
        error("Config Error: File not found at $path")
    end

    json_string = read(path, String)
    data = try
        JSON3.read(json_string)
    catch e
        error("Config Error: Invalid JSON syntax in $path")
    end
    
    # 1. Simulation Block
    if !haskey(data, :simulation) error("Config Error: Missing 'simulation' block") end
    sim = data.simulation
    N = validate_positive(get(sim, :N, 50000), "simulation.N")
    duration = validate_positive(Float64(get(sim, :duration, 10.0)), "simulation.duration")

    # 2. Output Block
    if !haskey(data, :output) error("Config Error: Missing 'output' block") end
    out = data.output
    mode = validate_choice(Symbol(get(out, :mode, "interactive")), [:interactive, :render, :export], "output.mode")
    output_file = get(out, :filename, "sandbox/output")
    res = validate_positive(get(out, :res, 800), "output.res")
    fps = validate_positive(get(out, :fps, 60), "output.fps")
    
    # 3. Physics Block
    if !haskey(data, :physics) error("Config Error: Missing 'physics' block") end
    phys = data.physics
    dt = validate_positive(Float32(get(phys, :dt, 0.002)), "physics.dt")
    solver = validate_choice(Symbol(get(phys, :solver, "CCD")), [:CCD], "physics.solver")
    
    # Gravity
    if !haskey(phys, :gravity) error("Config Error: Missing 'physics.gravity' block") end
    grav = phys.gravity
    grav_type = validate_choice(Symbol(get(grav, :type, "Zero")), [:Uniform, :Central, :Zero], "gravity.type")
    grav_params = Dict{Symbol, Any}(k => v for (k, v) in get(grav, :params, Dict()))
    
    # Boundary
    if !haskey(phys, :boundary) error("Config Error: Missing 'physics.boundary' block") end
    bound = phys.boundary
    bound_type = validate_choice(Symbol(get(bound, :type, "Circle")), [:Circle, :Box, :Ellipsoid, :InvertedCircle], "boundary.type")
    bound_params = Dict{Symbol, Any}(k => v for (k, v) in get(bound, :params, Dict()))
    
    # Deep Validation
    validate_boundary_params(bound_type, bound_params)
    validate_gravity_params(grav_type, grav_params)

    return SimulationConfig(
        N, duration, mode, output_file,
        dt, solver, grav_type, grav_params,
        bound_type, bound_params,
        res, fps
    )
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

function create_solver(cfg::SimulationConfig)
    if cfg.solver == :CCD
        return Physics.CCDSolver(cfg.dt, 1.0f0, 8)
    else
        error("Unknown Solver: $(cfg.solver)")
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