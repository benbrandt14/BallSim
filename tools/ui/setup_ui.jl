using Pkg

println("🛠️ Setting up UI Environment...")

# 1. Activate environment in current directory
Pkg.activate(@__DIR__)

# 2. Add Dependencies
println("📦 Adding Dependencies...")
dependencies = [
    "Genie",
    "Stipple",
    "StippleUI",
    "CairoMakie",
    "JSON3",
    "ImageIO"
]

Pkg.add(dependencies)

# 3. Link Local BallSim
println("🔗 Linking Local BallSim...")
Pkg.develop(path=joinpath(@__DIR__, "../.."))

println("✅ UI Setup Complete!")
println("   Run: julia --project=tools/ui tools/ui/app.jl")
