#!/usr/bin/env julia
using Pkg
Pkg.activate(@__DIR__) # Activate the environment of this file

using BallSim
# Pass command line args to your function
BallSim.command_line_main()
