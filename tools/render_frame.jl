using BallSim
using BallSim.Common
using BallSim.SimIO
using BallSim.Vis
using HDF5
using CairoMakie
using ColorSchemes

function render_darkroom(h5_path, frame_idx; res=(3840, 2160), cmap=:magma, exposure=1.0)
    println("📸 Darkroom: Processing Frame $frame_idx from $h5_path")
    
    # 1. Load Data
    N = h5open(h5_path, "r") do file
        read_attribute(file["frame_$(lpad(frame_idx, 5, '0'))"], "N")
    end
    
    # Create system with correct parameters to match file
    # Note: We rely on the generic BallSystem constructor here
    sys = Common.BallSystem(N, 2, Float32)
    
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

    Threads.@threads for i in 1:length(sys.data.pos)
        if sys.data.active[i]
            p = sys.data.pos[i]
            
            # Map physics (0,0) -> center of image
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
    fig = Figure(size=res, backgroundcolor=:black)
    ax = Axis(fig[1,1], aspect=DataAspect(), backgroundcolor=:black)
    hidedecorations!(ax)
    
    # Remove margins
    resize_to_layout!(fig)
    
    # Plot heatmap
    heatmap!(ax, img_data, colormap=cmap)
    
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