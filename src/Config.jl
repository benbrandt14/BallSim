module Config

using JSON3
using StaticArrays
using ..Common # OutputMode is now here
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

function load_config(path::String)
    json_string = read(path, String)
    data = JSON3.read(json_string)
    
    return SimulationConfig(
        data.simulation.N,
        Float64(data.simulation.duration),
        Symbol(data.output.mode),
        get(data.output, :filename, "sandbox/output"),
        
        Float32(get(data.physics, :dt, 0.002)),
        Symbol(get(data.physics, :solver, "CCD")),
        Symbol(data.physics.gravity.type),
        Dict{Symbol, Any}(k => v for (k, v) in data.physics.gravity.params),
        
        Symbol(data.physics.boundary.type),
        Dict{Symbol, Any}(k => v for (k, v) in data.physics.boundary.params),
        
        get(data.output, :res, 800),
        get(data.output, :fps, 60)
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