#!/usr/bin/env julia
using Pkg

# Pre-load GLMakie if interactive mode is requested
if "--mode" in ARGS && ("interactive" in ARGS || findfirst(==("interactive"), ARGS) != nothing)
    try
        using GLMakie
    catch e
        if e isa ArgumentError
            @warn "Interactive mode requested but GLMakie not found. Ensure you are running in the 'tools/interactive' environment (make run-interactive)."
        else
            @warn "Failed to load GLMakie: $e"
            rethrow(e)
        end
    end
end

using BallSim
# Pass command line args to your function
BallSim.command_line_main()
