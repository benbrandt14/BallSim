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

# Pre-load CUDA if requested via --backend cuda
if "--backend" in ARGS
    idx = findfirst(==("--backend"), ARGS)
    if idx !== nothing && length(ARGS) >= idx + 1 && ARGS[idx+1] == "cuda"
        try
            using CUDA
            println("🔌 CUDA loaded!")
        catch e
            @warn "CUDA requested but failed to load. Ensure 'CUDA' is installed in the active environment." exception = e
        end
    end
end

using BallSim
# Pass command line args to your function
BallSim.command_line_main()
