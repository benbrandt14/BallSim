using Pkg
Pkg.activate(joinpath(@__DIR__, "maintenance"))

using JuliaFormatter

println("🧹 Running JuliaFormatter...")
format(joinpath(@__DIR__, ".."), verbose = true)
