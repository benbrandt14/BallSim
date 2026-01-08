using Genie
using Stipple
using StippleUI
using CairoMakie
using JSON3
using Base64
using ImageIO

using BallSim
using BallSim.Config
using BallSim.Shapes
using BallSim.Fields
using BallSim.Common
using BallSim.Scenarios

# ==============================================================================
# MODEL
# ==============================================================================

@reactive mutable struct ConfigModel <: ReactiveModel
    # Scenario
    scenario_type::String = "Spiral"
    scenario_N::Int = 1000
    scenario_mass_min::Float64 = 1.0
    scenario_mass_max::Float64 = 1.0

    # Physics
    dimensions::Int = 2
    duration::Float64 = 10.0
    dt::Float64 = 0.002

    # Gravity
    gravity_type::String = "Zero" # Zero, Uniform, Central
    gravity_vector_x::Float64 = 0.0
    gravity_vector_y::Float64 = -9.8
    gravity_vector_z::Float64 = 0.0
    gravity_strength::Float64 = 1000.0

    # Boundary
    boundary_type::String = "Circle" # Circle, Box, Ellipsoid, InvertedCircle
    boundary_radius::Float64 = 1.0
    boundary_width::Float64 = 2.0
    boundary_height::Float64 = 2.0

    # Output
    output_res::Int = 800
    output_fps::Int = 60
    output_filename::String = "sim_output"

    # UI State
    preview_img::String = ""
    status_message::String = "Ready"
    is_running::Bool = false

    # Triggers
    refresh_preview_btn::Bool = false
    start_sim_btn::Bool = false
end

# ==============================================================================
# HELPERS
# ==============================================================================

function generate_preview(model::ConfigModel)
    f = Figure(size=(400, 400))
    ax = Axis(f[1,1], aspect=DataAspect())

    # Draw Boundary
    if model.boundary_type == "Circle" || model.boundary_type == "InvertedCircle"
        arc!(ax, Point2f(0,0), model.boundary_radius, 0, 2π, color=:black)
    elseif model.boundary_type == "Box"
        w, h = model.boundary_width, model.boundary_height
        rect = Rect2f(-w/2, -h/2, w, h)
        poly!(ax, rect, color=:transparent, strokewidth=2, strokecolor=:black)
    end

    # Draw Gravity Vector
    if model.gravity_type == "Uniform"
        arrows!(ax, [0.0], [0.0], [model.gravity_vector_x], [model.gravity_vector_y], lengthscale=0.1)
    elseif model.gravity_type == "Central"
        scatter!(ax, [0.0], [0.0], marker=:circle, color=:red)
    end

    # Limits
    lim = max(model.boundary_radius, model.boundary_width, model.boundary_height) * 1.2
    if lim == 0
        lim = 1.0
    end
    limits!(ax, -lim, lim, -lim, lim)

    # Export to Base64
    io = IOBuffer()
    show(io, MIME("image/png"), f)
    b64 = base64encode(take!(io))
    return "data:image/png;base64,$b64"
end

function build_config(model::ConfigModel)
    # Scenario
    scen_params = Dict{Symbol, Any}(
        :N => model.scenario_N,
        :mass_min => model.scenario_mass_min,
        :mass_max => model.scenario_mass_max
    )

    # Physics
    solver_params = Dict{Symbol, Any}(:restitution => 1.0, :substeps => 8)

    grav_params = Dict{Symbol, Any}()
    if model.gravity_type == "Uniform"
        grav_params[:vector] = model.dimensions == 2 ?
            [model.gravity_vector_x, model.gravity_vector_y] :
            [model.gravity_vector_x, model.gravity_vector_y, model.gravity_vector_z]
    elseif model.gravity_type == "Central"
        grav_params[:strength] = model.gravity_strength
    end

    bound_params = Dict{Symbol, Any}()
    if model.boundary_type in ["Circle", "InvertedCircle"]
        bound_params[:radius] = model.boundary_radius
    elseif model.boundary_type == "Box"
        bound_params[:width] = model.boundary_width
        bound_params[:height] = model.boundary_height
    end

    vis_config = Common.VisualizationConfig(mode=:density, aggregation=:sum)

    return SimulationConfig(
        Symbol(model.scenario_type), scen_params,
        model.duration, model.dimensions,
        Float32(model.dt), :CCD, solver_params,
        Symbol(model.gravity_type), grav_params,
        Symbol(model.boundary_type), bound_params,
        :render, model.output_filename, model.output_res, model.output_fps, "xy", vis_config
    )
end

# ==============================================================================
# UI LOGIC
# ==============================================================================

model = Stipple.init(ConfigModel)

on(model.refresh_preview_btn) do _
    model.preview_img[] = generate_preview(model)
    model.refresh_preview_btn[] = false
end

on(model.start_sim_btn) do _
    if model.is_running[]
        return
    end

    model.is_running[] = true
    model.status_message[] = "Running Simulation..."
    model.start_sim_btn[] = false # Reset toggle immediately

    cfg = build_config(model)

    # Async execution
    @async begin
        try
            BallSim.run_simulation(cfg)
            model.status_message[] = "Simulation Complete: $(cfg.output_file).mp4"
        catch e
            model.status_message[] = "Error: $e"
            println("Error running simulation: $e")
            Base.showerror(stdout, e, catch_backtrace())
        finally
            model.is_running[] = false
        end
    end
end

# Initialize Preview
model.preview_img[] = generate_preview(model)

# ==============================================================================
# LAYOUT
# ==============================================================================

function ui()
    dashboard(
        vm(model),
        [
            heading("BallSim Configurator"),

            row([
                cell(class="st-module", [
                    h4("Scenario"),
                    select(:scenario_type, options=["Spiral"], label="Type"),
                    numberfield(:scenario_N, label="Particles (N)"),
                    numberfield(:scenario_mass_min, label="Min Mass"),
                    numberfield(:scenario_mass_max, label="Max Mass")
                ]),

                cell(class="st-module", [
                    h4("Physics"),
                    select(:dimensions, options=[2, 3], label="Dims"),
                    numberfield(:duration, label="Duration (s)"),
                    numberfield(:dt, label="Time Step (dt)"),

                    h5("Gravity"),
                    select(:gravity_type, options=["Zero", "Uniform", "Central"], label="Gravity Type"),
                    numberfield(:gravity_vector_y, label="Gravity Y (Uniform)"),
                    numberfield(:gravity_strength, label="Strength (Central)")
                ])
            ]),

            row([
                cell(class="st-module", [
                    h4("Boundary"),
                    select(:boundary_type, options=["Circle", "Box", "InvertedCircle"], label="Type"),
                    numberfield(:boundary_radius, label="Radius"),
                    numberfield(:boundary_width, label="Width"),
                    numberfield(:boundary_height, label="Height")
                ]),

                cell(class="st-module", [
                    h4("Output"),
                    textfield(:output_filename, label="Filename"),
                    numberfield(:output_res, label="Resolution"),
                    numberfield(:output_fps, label="FPS")
                ])
            ]),

            row([
                cell([
                    btn("Refresh Preview", @click("refresh_preview_btn = true"), color="primary"),
                    br(),
                    imageview(src=:preview_img, style="max-width: 400px; border: 1px solid #ccc;")
                ]),
                cell([
                    h4("Status"),
                    p("{{ status_message }}"),
                    btn("Start Simulation", @click("start_sim_btn = true"), :disable => :is_running, color="positive")
                ])
            ])
        ],
        title = "BallSim Configurator"
    )
end

route("/") do
    ui() |> html
end

# ==============================================================================
# MAIN
# ==============================================================================

up(8000; async=false)
