using Pkg

println("🛠️ Setting up Interactive Environment...")

# 1. Activate environment in tools/interactive
Pkg.activate(joinpath(@__DIR__, "interactive"))

# 2. Link Local BallSim (Must be done before adding other deps)
println("🔗 Linking Local BallSim...")
Pkg.develop(path = joinpath(@__DIR__, ".."))

# 3. Add Dependencies
println("📦 Adding Dependencies...")
dependencies = ["GLMakie"]

Pkg.add(dependencies)

println("✅ Interactive Setup Complete!")
println("   Run: make run-interactive")
