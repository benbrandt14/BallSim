using JuliaFormatter
using Pkg

Pkg.activate(".")
println("Running JuliaFormatter...")
format(".")
println("Formatting complete.")
