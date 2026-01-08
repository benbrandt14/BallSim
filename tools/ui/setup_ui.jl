using Pkg

println("🛠️  Setting up BallSim UI Environment...")

# 1. Activate tools/ui environment
Pkg.activate(@__DIR__)

# 2. Add local BallSim dependency
println("📦 Linking local BallSim package...")
Pkg.develop(path=joinpath(@__DIR__, "..", ".."))

# 3. Instantiate other dependencies
println("📥 Instantiating dependencies...")
Pkg.instantiate()

println("✅ Setup Complete! You can now run the UI with:")
println("   julia --project=tools/ui tools/ui/app.jl")
