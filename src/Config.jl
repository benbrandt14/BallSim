module Config

using YAML
using StaticArrays
using ..Common
using ..Shapes
using ..Fields
using ..Physics
using ..Scenarios

struct SimulationConfig
    # Scenario
    scenario_type::Symbol
    scenario_params::Dict{Symbol,Any}

    # Simulation meta
    duration::Float64
    dimensions::Int

    # Physics
    dt::Float32
    solver::Symbol
    solver_params::Dict{Symbol,Any}

    gravity_type::Symbol
    gravity_params::Dict{Symbol,Any}

    boundary_type::Symbol
    boundary_params::Dict{Symbol,Any}

    # Output
    mode::Symbol
    output_file::String
    res::Int
    fps::Int
    interval::Int # Step interval for export
    projection::Any # Can be String ("xy") or Dict (custom)
    vis_config::Common.VisualizationConfig
end

function modify_config(cfg::SimulationConfig; kwargs...)
    # Helper to reconstruct SimulationConfig with overrides
    # kwargs can contain keys matching the struct fields

    # We use a Dict to hold current values
    fields = fieldnames(SimulationConfig)
    current_values = Dict(f => getfield(cfg, f) for f in fields)

    # Update with kwargs
    for (k, v) in kwargs
        if haskey(current_values, k)
            current_values[k] = v
        end
    end

    # Reconstruct
    return SimulationConfig(
        current_values[:scenario_type],
        current_values[:scenario_params],
        current_values[:duration],
        current_values[:dimensions],
        current_values[:dt],
        current_values[:solver],
        current_values[:solver_params],
        current_values[:gravity_type],
        current_values[:gravity_params],
        current_values[:boundary_type],
        current_values[:boundary_params],
        current_values[:mode],
        current_values[:output_file],
        current_values[:res],
        current_values[:fps],
        current_values[:interval],
        current_values[:projection],
        current_values[:vis_config],
    )
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

function validate_boundary_params(type, params, dims)
    if type in (:Circle, :InvertedCircle)
        if !haskey(params, :radius)
            error("Config Error: Boundary '$type' requires 'radius'.")
        end
        if params[:radius] <= 0
            error("Config Error: 'radius' must be positive.")
        end
    elseif type == :Box
        if !haskey(params, :width) || !haskey(params, :height)
            error("Config Error: Box requires 'width' and 'height'.")
        end
        if params[:width] <= 0 || params[:height] <= 0
            error("Config Error: Box dims must be positive.")
        end

        if dims == 3
            if !haskey(params, :depth)
                error("Config Error: 3D Box requires 'depth'.")
            end
            if params[:depth] <= 0
                error("Config Error: Box depth must be positive.")
            end
        end
    elseif type == :Ellipsoid
        if !haskey(params, :rx) || !haskey(params, :ry)
            error("Config Error: Ellipsoid requires 'rx' and 'ry'.")
        end
        if params[:rx] <= 0 || params[:ry] <= 0
            error("Config Error: Ellipsoid radii must be positive.")
        end
    elseif type == :Polygon
        if !haskey(params, :vertices)
            error("Config Error: Polygon requires 'vertices'.")
        end
    elseif type == :Rotating
        if !haskey(params, :angular_velocity) || !haskey(params, :inner)
            error("Config Error: Rotating requires 'angular_velocity' and 'inner'.")
        end
    end
end

function validate_gravity_params(type, params, dims)
    if type == :Uniform
        if !haskey(params, :vector)
            error("Config Error: Uniform gravity requires 'vector'.")
        end
        if length(params[:vector]) != dims
            error("Config Error: Gravity vector must have $dims components.")
        end
    elseif type == :Central
        if !haskey(params, :strength)
            error("Config Error: Central gravity requires 'strength'.")
        end
    elseif type == :Vortex
        if !haskey(params, :strength)
            error("Config Error: Vortex requires 'strength'.")
        end
    end
end

# ==============================================================================
# LOADER
# ==============================================================================

function symbol_keys(d::AbstractDict)
    return Dict{Symbol,Any}(Symbol(k) => (v isa AbstractDict ? symbol_keys(v) : v) for (k, v) in d)
end

function load_config(path::String)
    if !isfile(path)
        error("Config Error: File not found at $path")
    end

    data = try
        YAML.load_file(path)
    catch e
        error("Invalid YAML: $e")
    end

    # Convert string keys to symbols
    data = symbol_keys(data)

    # 1. Simulation / Scenario
    if !haskey(data, :simulation)
        error("Missing 'simulation' block")
    end
    sim = data[:simulation]

    scen_type = Symbol(get(sim, :type, "Spiral"))
    scen_params = get(sim, :params, Dict())

    # Backward compat for top-level N
    if haskey(sim, :N)
        scen_params[:N] = validate_positive(sim[:N], "simulation.N")
    end

    duration = validate_positive(Float64(get(sim, :duration, 10.0)), "simulation.duration")
    dimensions =
        validate_choice(Int(get(sim, :dimensions, 2)), [2, 3], "simulation.dimensions")

    # 2. Physics
    if !haskey(data, :physics)
        error("Missing 'physics' block")
    end
    phys = data[:physics]
    dt = validate_positive(Float32(get(phys, :dt, 0.002)), "physics.dt")
    solver = validate_choice(Symbol(get(phys, :solver, "CCD")), [:CCD], "physics.solver")

    solver_params = get(phys, :solver_params, Dict())

    # Gravity
    if !haskey(phys, :gravity)
        error("Missing 'physics.gravity'")
    end
    grav = phys[:gravity]
    grav_type = validate_choice(
        Symbol(get(grav, :type, "Zero")),
        [:Uniform, :Central, :Zero, :Vortex],
        "gravity.type",
    )
    grav_params = get(grav, :params, Dict())
    validate_gravity_params(grav_type, grav_params, dimensions)

    # Boundary
    if !haskey(phys, :boundary)
        error("Missing 'physics.boundary'")
    end
    bound = phys[:boundary]
    bound_type = validate_choice(
        Symbol(get(bound, :type, "Circle")),
        [:Circle, :Box, :Ellipsoid, :InvertedCircle, :Polygon, :Rotating],
        "boundary.type",
    )
    bound_params = get(bound, :params, Dict())
    validate_boundary_params(bound_type, bound_params, dimensions)

    # 3. Output
    if !haskey(data, :output)
        error("Missing 'output' block")
    end
    out = data[:output]
    mode = validate_choice(
        Symbol(get(out, :mode, "interactive")),
        [:interactive, :render, :export],
        "output.mode",
    )
    output_file = get(out, :filename, "sandbox/output")
    res = validate_positive(get(out, :res, 800), "output.res")
    fps = validate_positive(get(out, :fps, 60), "output.fps")
    interval = validate_positive(Int(get(out, :interval, 10)), "output.interval")
    projection = get(out, :projection, "xy")

    vis_data = get(out, :visualization, Dict())
    v_mode = Symbol(get(vis_data, :mode, "density"))
    v_agg = Symbol(get(vis_data, :aggregation, "sum"))
    vis_config = Common.VisualizationConfig(mode = v_mode, aggregation = v_agg)

    return SimulationConfig(
        scen_type,
        scen_params,
        duration,
        dimensions,
        dt,
        solver,
        solver_params,
        grav_type,
        grav_params,
        bound_type,
        bound_params,
        mode,
        output_file,
        res,
        fps,
        interval,
        projection,
        vis_config,
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
            return Scenarios.SpiralScenario(
                N = Int(N),
                mass_min = Float32(m_min),
                mass_max = Float32(m_max),
            )
        elseif cfg.dimensions == 3
            return Scenarios.SpiralScenario3D(
                N = Int(N),
                mass_min = Float32(m_min),
                mass_max = Float32(m_max),
            )
        end
    elseif t == :Tumbler
        N = get(p, :N, 1000)
        return Scenarios.TumblerScenario(N = Int(N))
    else
        error("Unknown Scenario Type: $t")
    end
end

function create_solver(cfg::SimulationConfig)
    if cfg.solver == :CCD
        rest = Float32(get(cfg.solver_params, :restitution, 1.0))
        sub = Int(get(cfg.solver_params, :substeps, 8))
        return Physics.CCDSolver(cfg.dt, rest, sub)
    else
        error("Unknown Solver: $(cfg.solver)")
    end
end

function create_boundary_from_dict(type::Symbol, params::AbstractDict, dims::Int)
    if dims == 3
        if type == :Circle || type == :Circle3D
            return Shapes.Circle3D(Float32(params[:radius]))
        elseif type == :Box
            return Shapes.Box3D(Float32(params[:width]), Float32(params[:height]), Float32(params[:depth]))
        elseif type == :InvertedCircle
            return Shapes.Inverted(Shapes.Circle3D(Float32(params[:radius])))
        else
            error("Boundary '$type' not supported in 3D yet.")
        end
    else # 2D
        if type == :Circle
            return Shapes.Circle(Float32(params[:radius]))
        elseif type == :Box
            return Shapes.Box(Float32(params[:width]), Float32(params[:height]))
        elseif type == :Ellipsoid
            return Shapes.Ellipsoid(Float32(params[:rx]), Float32(params[:ry]))
        elseif type == :InvertedCircle
            return Shapes.Inverted(Shapes.Circle(Float32(params[:radius])))
        elseif type == :Polygon
            raw_verts = params[:vertices]
            verts = [SVector{2,Float32}(Float32(v[1]), Float32(v[2])) for v in raw_verts]
            return Shapes.ConvexPolygon(verts)
        elseif type == :Rotating
            w = Float32(params[:angular_velocity])
            inner_raw = params[:inner]
            inner_type = Symbol(inner_raw[:type])
            inner_params = inner_raw[:params]
            inner_b = create_boundary_from_dict(inner_type, inner_params, dims)
            return Shapes.Rotating(inner_b, w)
        else
            error("Unknown Boundary Type: $type")
        end
    end
end

function create_boundary(cfg::SimulationConfig)
    return create_boundary_from_dict(cfg.boundary_type, cfg.boundary_params, cfg.dimensions)
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
            mode = Symbol(get(p, :mode, "attractor")),
        )
    elseif t == :Vortex
        c = get(p, :center, zeros(Float32, cfg.dimensions))
        if cfg.dimensions == 2
            pos = SVector(Float32(c[1]), Float32(c[2]))
        elseif cfg.dimensions == 3
            pos = SVector(Float32(c[1]), Float32(c[2]), Float32(c[3]))
        end
        return Fields.VortexField(
            pos,
            Float32(p[:strength]),
            cutoff = Float32(get(p, :cutoff, 0.1)),
        )
    elseif t == :Zero
        if cfg.dimensions == 2
            return (p, v, m, t) -> SVector(0.0f0, 0.0f0)
        elseif cfg.dimensions == 3
            return (p, v, m, t) -> SVector(0.0f0, 0.0f0, 0.0f0)
        end
    else
        error("Unknown Gravity Type: $t")
    end
end

function parse_projection(p)
    if p == "xy"
        return (SVector(1.0f0, 0.0f0, 0.0f0), SVector(0.0f0, 1.0f0, 0.0f0))
    elseif p == "xz"
        return (SVector(1.0f0, 0.0f0, 0.0f0), SVector(0.0f0, 0.0f0, 1.0f0))
    elseif p == "yz"
        return (SVector(0.0f0, 1.0f0, 0.0f0), SVector(0.0f0, 0.0f0, 1.0f0))
    elseif p isa AbstractDict && haskey(p, :u) && haskey(p, :v)
        u = p[:u]
        v = p[:v]
        return (SVector{3,Float32}(u...), SVector{3,Float32}(v...))
    else
        # Default fallback or error?
        # If 3D but no valid projection, default to xy
        return (SVector(1.0f0, 0.0f0, 0.0f0), SVector(0.0f0, 1.0f0, 0.0f0))
    end
end

function create_mode(cfg::SimulationConfig)
    u, v = parse_projection(cfg.projection)

    if cfg.mode == :interactive
        return Common.InteractiveMode(
            res = cfg.res,
            fps = cfg.fps,
            u = u,
            v = v,
            vis_config = cfg.vis_config,
        )
    elseif cfg.mode == :render
        mkpath(dirname(cfg.output_file))
        fname =
            endswith(cfg.output_file, ".mp4") ? cfg.output_file : "$(cfg.output_file).mp4"
        return Common.RenderMode(
            fname,
            fps = cfg.fps,
            res = cfg.res,
            u = u,
            v = v,
            vis_config = cfg.vis_config,
        )
    elseif cfg.mode == :export
        mkpath(dirname(cfg.output_file))
        fname = cfg.output_file
        # Default to h5 if no known extension
        if !endswith(fname, ".h5") && !endswith(fname, ".vtp") && !endswith(fname, ".vtu")
            fname = "$(fname).h5"
        end
        return Common.ExportMode(fname, interval = cfg.interval)
    else
        error("Unknown Mode: $(cfg.mode)")
    end
end

end
