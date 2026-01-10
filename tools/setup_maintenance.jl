using Pkg

println("🛠️ Setting up Maintenance Environment...")

# 1. Activate environment
Pkg.activate(joinpath(@__DIR__, "maintenance"))

# 2. Link Local BallSim
println("🔗 Linking Local BallSim...")
Pkg.develop(path = joinpath(@__DIR__, ".."))

# 3. Instantiate to install JET and JuliaFormatter
println("📦 Instantiating dependencies...")
Pkg.instantiate()

println("✅ Maintenance Setup Complete!")
