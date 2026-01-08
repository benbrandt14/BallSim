using Genie
using Stipple
using StippleUI
using BallSim
using BallSim.Config
using JSON3
using CairoMakie
using Dates
using Base64

# ==============================================================================
# DATA MODEL
# ==============================================================================

@reactive mutable struct ConfigModel <: ReactiveModel
    # Scenario
    scenario_type::String = "Spiral"
    scenario_N::Int = 1000
    scenario_mass_min::Float64 = 1.0
    scenario_mass_max::Float64 = 1.0

    # Physics
    dimensions::Int = 2
    dt::Float64 = 0.002
    gravity_type::String = "Uniform"
    gravity_x::Float64 = 0.0
    gravity_y::Float64 = -5.0
    gravity_strength::Float64 = 100.0

    boundary_type::String = "Circle"
    boundary_radius::Float64 = 1.0
    boundary_width::Float64 = 2.0
    boundary_height::Float64 = 2.0

    # Output
    duration::Float64 = 10.0
    output_res::Int = 800
    output_fps::Int = 60

    # UI State
    preview_img::String = ""
    is_running::Bool = false
    status_message::String = "Ready"

    # Button Triggers
    start_sim_btn::Bool = false
    refresh_preview_btn::Bool = false
end

# ==============================================================================
# LOGIC
# ==============================================================================

function generate_preview(model)
    # 1. Create dummy Boundary
    fig = Figure(size=(400, 400), backgroundcolor=:white)
    ax = Axis(fig[1,1], aspect=DataAspect())

    # Draw Boundary
    if model.boundary_type == "Circle"
        arc!(ax, Point2f(0,0), Float32(model.boundary_radius), 0f0, 2f0*π, color=:black)
        xlims!(ax, -model.boundary_radius*1.2, model.boundary_radius*1.2)
        ylims!(ax, -model.boundary_radius*1.2, model.boundary_radius*1.2)
    elseif model.boundary_type == "Box"
        w, h = model.boundary_width, model.boundary_height
        rect = Rect2f(-w/2, -h/2, w, h)
        poly!(ax, rect, color=(:white, 0.0), strokecolor=:black, strokewidth=2)
        xlims!(ax, -w/2 * 1.5, w/2 * 1.5)
        ylims!(ax, -h/2 * 1.5, h/2 * 1.5)
    end

    # Draw Gravity Vector (if uniform)
    if model.gravity_type == "Uniform"
        arrows!(ax, [0.0], [0.0], [model.gravity_x], [model.gravity_y], color=:red, lengthscale=0.1)
    end

    # Save to Base64
    path = tempname() * ".png"
    save(path, fig)
    base64_str = base64encode(read(path))
    return "data:image/png;base64,$base64_str"
end

function run_sim_task(model)
    model.is_running = true
    model.status_message = "Simulation Started..."

    # Map Model -> SimulationConfig
    scen_params = Dict{Symbol,Any}(
        :N => model.scenario_N,
        :mass_min => model.scenario_mass_min,
        :mass_max => model.scenario_mass_max
    )

    grav_params = Dict{Symbol,Any}()
    if model.gravity_type == "Uniform"
        grav_params[:vector] = [model.gravity_x, model.gravity_y]
    elseif model.gravity_type == "Central"
        grav_params[:strength] = model.gravity_strength
        grav_params[:center] = [0.0, 0.0] # Default
    end

    bound_params = Dict{Symbol,Any}()
    if model.boundary_type == "Circle"
        bound_params[:radius] = model.boundary_radius
    elseif model.boundary_type == "Box"
        bound_params[:width] = model.boundary_width
        bound_params[:height] = model.boundary_height
    end

    # Generate Output File
    timestamp = Dates.format(now(), "YYYYmmdd_HHMMSS")
    outfile = "sandbox/ui_run_$timestamp"

    cfg = Config.SimulationConfig(
        Symbol(model.scenario_type), scen_params,
        model.duration,
        model.dimensions,
        Float32(model.dt),
        :CCD, Dict{Symbol,Any}(:restitution=>1.0, :substeps=>8),
        Symbol(model.gravity_type), grav_params,
        Symbol(model.boundary_type), bound_params,
        :render, outfile, model.output_res, model.output_fps, "xy"
    )

    try
        BallSim.run_simulation(cfg)
        model.status_message = "✅ Simulation Complete! Saved to $outfile.mp4"
    catch e
        model.status_message = "❌ Error: $(e)"
        @error e
    finally
        model.is_running = false
    end
end

# ==============================================================================
# UI LAYOUT
# ==============================================================================

function ui(model)
    dashboard(vm(model), [
        heading("BallSim Configurator"),

        row([
            cell(class="st-col-4", [
                h4("Scenario"),
                select(:scenario_type, options=["Spiral"], label="Type"),
                numberfield(:scenario_N, label="Particle Count (N)", step=100),

                h4("Physics"),
                select(:gravity_type, options=["Uniform", "Central", "Zero"], label="Gravity Type"),

                # Dynamic Gravity Fields
                row([
                    cell(numberfield(:gravity_x, label="Gravity X")),
                    cell(numberfield(:gravity_y, label="Gravity Y"))
                ], @showif("gravity_type == 'Uniform'")),

                select(:boundary_type, options=["Circle", "Box"], label="Boundary Type"),
                 # Dynamic Boundary Fields
                row([
                    cell(numberfield(:boundary_radius, label="Radius"))
                ], @showif("boundary_type == 'Circle'")),
                 row([
                    cell(numberfield(:boundary_width, label="Width")),
                    cell(numberfield(:boundary_height, label="Height"))
                ], @showif("boundary_type == 'Box'")),

                h4("Actions"),
                btn("Update Preview", @click("refresh_preview_btn = !refresh_preview_btn"), color="primary"),
                btn("Run Simulation", @click("start_sim_btn = true"), color="positive", :loading => :is_running, :disable => :is_running)
            ]),

            cell(class="st-col-8", [
                h4("Preview"),
                imageview(src=:preview_img, style="max-width: 100%; border: 1px solid #ccc;"),

                h4("Status"),
                p("{{ status_message }}")
            ])
        ])
    ], title="BallSim Configurator")
end

# ==============================================================================
# MAIN
# ==============================================================================

model = Stipple.init(ConfigModel)

on(model.gravity_type) do _
    model.preview_img = generate_preview(model)
end
on(model.boundary_type) do _
    model.preview_img = generate_preview(model)
end
on(model.scenario_N) do _
    model.preview_img = generate_preview(model)
end

on(model.refresh_preview_btn) do _
    model.preview_img = generate_preview(model)
end

# Button Handlers
on(model.start_sim_btn) do clicked
    if clicked
        # Reset trigger immediately so it can be clicked again later if needed
        model.start_sim_btn = false
        if !model.is_running
             @async run_sim_task(model)
        end
    end
end

# Generate initial preview
model.preview_img = generate_preview(model)

route("/") do
    ui(model) |> html
end

up(8000; async=false) # Blocking call for script execution
