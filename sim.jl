#!/usr/bin/env julia
using Pkg
Pkg.activate(@__DIR__) # Activate the environment of this file

using BallSim

# Attempt to load GLMakie for interactive/render modes if available
try
    using GLMakie
catch
    # Ignore if not available (headless)
end

# Pass command line args to your function
BallSim.command_line_main()
