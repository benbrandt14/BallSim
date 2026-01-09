using Genie
using Stipple
using Stipple.ReactiveTools
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
# HELPERS
# ==============================================================================

function generate_preview(model)
    f = Figure(size=(400, 400))
    ax = Axis(f[1,1], aspect=DataAspect())

    # Draw Boundary
    b_type = model.boundary_type[]
    if b_type == "Circle" || b_type == "InvertedCircle"
        arc!(ax, Point2f(0,0), model.boundary_radius[], 0, 2π, color=:black)
    elseif b_type == "Box"
        w, h = model.boundary_width[], model.boundary_height[]
        rect = Rect2f(-w/2, -h/2, w, h)
        poly!(ax, rect, color=:transparent, strokewidth=2, strokecolor=:black)
    end

    # Draw Gravity Vector
    g_type = model.gravity_type[]
    if g_type == "Uniform"
        arrows!(ax, [0.0], [0.0], [model.gravity_vector_x[]], [model.gravity_vector_y[]], lengthscale=0.1)
    elseif g_type == "Central"
        scatter!(ax, [0.0], [0.0], marker=:circle, color=:red)
    end

    # Limits
    lim = max(model.boundary_radius[], model.boundary_width[], model.boundary_height[]) * 1.2
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

function build_config(model)
    # Scenario
    scen_params = Dict{Symbol, Any}(
        :N => model.scenario_N[],
        :mass_min => model.scenario_mass_min[],
        :mass_max => model.scenario_mass_max[]
    )

    # Physics
    solver_params = Dict{Symbol, Any}(:restitution => 1.0, :substeps => 8)

    grav_params = Dict{Symbol, Any}()
    g_type = model.gravity_type[]
    if g_type == "Uniform"
        grav_params[:vector] = model.dimensions[] == 2 ?
            [model.gravity_vector_x[], model.gravity_vector_y[]] :
            [model.gravity_vector_x[], model.gravity_vector_y[], model.gravity_vector_z[]]
    elseif g_type == "Central"
        grav_params[:strength] = model.gravity_strength[]
    end

    bound_params = Dict{Symbol, Any}()
    b_type = model.boundary_type[]
    if b_type in ["Circle", "InvertedCircle"]
        bound_params[:radius] = model.boundary_radius[]
    elseif b_type == "Box"
        bound_params[:width] = model.boundary_width[]
        bound_params[:height] = model.boundary_height[]
    end

    vis_config = Common.VisualizationConfig(mode=:density, aggregation=:sum)

    return SimulationConfig(
        Symbol(model.scenario_type[]), scen_params,
        model.duration[], model.dimensions[],
        Float32(model.dt[]), :CCD, solver_params,
        Symbol(g_type), grav_params,
        Symbol(b_type), bound_params,
        :render, model.output_filename[], model.output_res[], model.output_fps[], "xy", vis_config
    )
end

# ==============================================================================
# MODEL & UI LOGIC
# ==============================================================================

@app ConfigApp begin
    # Scenario
    @in scenario_type = "Spiral"
    @in scenario_N = 1000
    @in scenario_mass_min = 1.0
    @in scenario_mass_max = 1.0

    # Physics
    @in dimensions = 2
    @in duration = 10.0
    @in dt = 0.002

    # Gravity
    @in gravity_type = "Zero" # Zero, Uniform, Central
    @in gravity_vector_x = 0.0
    @in gravity_vector_y = -9.8
    @in gravity_vector_z = 0.0
    @in gravity_strength = 1000.0

    # Boundary
    @in boundary_type = "Circle" # Circle, Box, Ellipsoid, InvertedCircle
    @in boundary_radius = 1.0
    @in boundary_width = 2.0
    @in boundary_height = 2.0

    # Output
    @in output_res = 800
    @in output_fps = 60
    @in output_filename = "sim_output"

    # UI State
    @out preview_img = ""
    @out status_message = "Ready"
    @in is_running = false

    # Triggers
    @in refresh_preview_btn = false
    @in start_sim_btn = false

    # Event Handlers
    @onchange refresh_preview_btn begin
        if refresh_preview_btn
            preview_img = generate_preview(model)
            refresh_preview_btn = false
        end
    end

    @onchange start_sim_btn begin
        if start_sim_btn
            if is_running
                return
            end

            is_running = true
            status_message = "Running Simulation..."
            start_sim_btn = false

            cfg = build_config(model)

            @async begin
                try
                    BallSim.run_simulation(cfg)
                    status_message = "Simulation Complete: $(cfg.output_file).mp4"
                catch e
                    status_message = "Error: $e"
                    println("Error running simulation: $e")
                    Base.showerror(stdout, e, catch_backtrace())
                finally
                    is_running = false
                end
            end
        end
    end

    @onchange isready begin
        preview_img = generate_preview(model)
    end
end

# ==============================================================================
# LAYOUT
# ==============================================================================

# Initialize the model instance
model = @init(ConfigApp)

function ui()
    page(model,
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

@page("/", ui)

# ==============================================================================
# MAIN
# ==============================================================================

up(8000; async=false)
