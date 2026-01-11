using JET
using Pkg

Pkg.activate(".")
Pkg.instantiate()

using BallSim

println("Running JET analysis...")
report = report_package("BallSim"; target_modules=(BallSim,))
println(report)
