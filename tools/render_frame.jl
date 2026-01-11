using BallSim
using BallSim.Common
using BallSim.SimIO
using BallSim.Vis
using HDF5
using CairoMakie
using ColorSchemes

function render_darkroom(
    h5_path,
    frame_idx;
    res = (3840, 2160),
    cmap = :magma,
    exposure = 1.0,
)
    println("📸 Darkroom: Processing Frame $frame_idx from $h5_path")

    # 1. Load Data
    N = 0
    dims = 2 # Default to 2D

    h5open(h5_path, "r") do file
        # Read N from the specific frame
        frame_grp = file["frame_$(lpad(frame_idx, 5, '0'))"]
        N = read_attribute(frame_grp, "N")

        # Try to detect dimensions from file-level "scenario" attribute
        if haskey(HDF5.attributes(file), "scenario")
            scen_str = read_attribute(file, "scenario")
            # Parse "BallSystem{D,"
            m = match(r"BallSystem\{(\d+),", scen_str)
            if m !== nothing
                dims = parse(Int, m.captures[1])
                println("   Detected Dimensions: $dims (from $scen_str)")
            else
                println("   Warning: Could not parse dimensions from '$scen_str'. Defaulting to 2D.")
            end
        else
            println("   Warning: No 'scenario' attribute found. Defaulting to 2D.")
        end
    end

    # Create system with correct parameters to match file
    sys = Common.BallSystem(N, dims, Float32)

    h5open(h5_path, "r") do file
        SimIO.load_frame!(sys, file, frame_idx)
    end
    println("   Loaded $(N) particles. Time: $(sys.t)")

    # 2. High-Res Accumulation Buffer
    w, h = res
    density = zeros(Float32, w, h)

    println("   Accumulating density ($w x $h)...")

    limit = 1.1
    scale_x = w / (2 * limit)
    scale_y = h / (2 * limit)

    # Aspect Ratio Correction
    aspect = w / h
    if aspect > 1.0
        # Wide screen: Scale by Height
        scale_x = scale_y
    else
        # Tall screen: Scale by Width
        scale_y = scale_x
    end

    # Centering offsets
    # We want (0,0) in physics to map to (w/2, h/2)
    center_x = w / 2
    center_y = h / 2

    Threads.@threads for i = 1:length(sys.data.pos)
        if sys.data.active[i]
            p = sys.data.pos[i]

            # Map physics (0,0) -> center of image
            # For 3D, this simply projects onto XY plane (p[1], p[2])
            # which works because SVector{3} supports indexing [1] and [2]
            px = (p[1] * scale_x) + center_x
            py = (p[2] * scale_y) + center_y

            ix = floor(Int, px)
            iy = floor(Int, py)

            if 1 <= ix <= w && 1 <= iy <= h
                # Race condition note:
                # Multiple threads might write to the same pixel here. 
                # For visualization purposes, the error (missing 1.0 density) is negligible 
                # compared to the cost of atomic locking on a 8MP image.
                density[ix, iy] += 1.0f0
            end
        end
    end

    # 3. Tone Mapping
    println("   Developing (Log Scale)...")
    # Add small epsilon to avoid log(0)
    img_data = log1p.(density .* exposure)

    # 4. Render
    println("   Printing...")
    fig = Figure(size = res, backgroundcolor = :black)
    ax = Axis(fig[1, 1], aspect = DataAspect(), backgroundcolor = :black)
    hidedecorations!(ax)

    # Remove margins
    resize_to_layout!(fig)

    # Plot heatmap
    heatmap!(ax, img_data, colormap = cmap)

    # Generate filename
    dir = dirname(h5_path)
    base = splitext(basename(h5_path))[1]
    out_name = joinpath(dir, "$(base)_frame$(frame_idx).png")

    save(out_name, fig)
    println("✅ Saved to $out_name")
end

# CLI Wrapper
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 2
        println("Usage: julia tools/render_frame.jl <h5_file> <frame_index>")
        exit(1)
    end
    render_darkroom(ARGS[1], parse(Int, ARGS[2]))
end
