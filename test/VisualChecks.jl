module VisualChecks
using LinearAlgebra
using StaticArrays
using Printf
using BallSim.Common

function print_sdf_slice(boundary, limits=1.2, res=20)
    println("\n--- SDF Visual Check: $(typeof(boundary)) ---")
    xs = range(-limits, limits, length=res * 2)
    ys = range(limits, -limits, length=res)

    for y in ys
        line = ""
        for x in xs
            p = SVector(Float32(x), Float32(y))
            d = Common.sdf(boundary, p, 0.0f0)
            if abs(d) < 0.05
                line *= "OO"
            elseif d < 0
                line *= ".."
            else
                line *= "  "
            end
        end
        println(line)
    end
end

function print_vector_field(boundary, limits=1.2, res=10)
    println("\n--- Gradient Vector Field: $(typeof(boundary)) ---")
    xs = range(-limits, limits, length=res)
    ys = range(limits, -limits, length=res)

    for y in ys
        line = ""
        for x in xs
            p = SVector(Float32(x), Float32(y))
            n = Common.normal(boundary, p, 0.0f0)

            # Map normal to ASCII arrow
            angle = atan(n[2], n[1])
            # 8-way quantization
            sector = mod(round(Int, 8 * angle / (2π)) + 8, 8)

            char = if sector == 0
                "→ "      # Right
            elseif sector == 1
                "↗ "  # TR
            elseif sector == 2
                "↑ "  # Up
            elseif sector == 3
                "↖ "  # TL
            elseif sector == 4
                "← "  # Left
            elseif sector == 5
                "↙ "  # BL
            elseif sector == 6
                "↓ "  # Down
            elseif sector == 7
                "↘ "  # BR
            else
                "? "
            end

            if Common.sdf(boundary, p, 0.0f0) < 0
                # Invert color/char for inside? No, just keep direction.
                # Let's mark inside with lowercase or brackets if needed.
            end
            line *= char
        end
        println(line)
    end
end

function check_gradients(boundary, points)
    # ... (Keep existing implementation from previous step) ...
    # (Copy the check_gradients function from the previous successful run here)
    println("\n--- Gradient Consistency Check ---")
    passes = true
    for p in points
        n_analytic = Common.normal(boundary, p, 0.0f0)
        ϵ = 0.0001f0
        d_c = Common.sdf(boundary, p, 0.0f0)
        d_x = Common.sdf(boundary, p + SVector(ϵ, 0), 0.0f0)
        d_y = Common.sdf(boundary, p + SVector(0, ϵ), 0.0f0)

        # Central difference for better accuracy
        d_xm = Common.sdf(boundary, p - SVector(ϵ, 0), 0.0f0)
        d_ym = Common.sdf(boundary, p - SVector(0, ϵ), 0.0f0)

        n_num = normalize(SVector((d_x - d_xm) / (2ϵ), (d_y - d_ym) / (2ϵ)))
        alignment = dot(n_analytic, n_num)

        if alignment < 0.99
            @printf "❌ Fail at (%.2f, %.2f): Alignment %.4f\n" p[1] p[2] alignment
            passes = false
        end
    end
    if passes
        println("✅ Gradients OK")
    end
    return passes
end
end
