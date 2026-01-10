using Pkg
Pkg.activate(joinpath(@__DIR__, "maintenance"))

using JET
using BallSim

println("🔎 Running JET Analysis on BallSim...")
report_package(BallSim)
