module CLI

using ..Config

export parse_args

function parse_args(args::Vector{String})
    overrides = Dict{String, Any}()
    config_file = "config.json" # Default

    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--config" || arg == "-c"
            if i + 1 <= length(args)
                config_file = args[i+1]
                i += 1
            else
                println("Warning: No config file specified after $arg")
            end
        elseif startswith(arg, "--mode=")
            val = split(arg, "=")[2]
            if !haskey(overrides, "output")
                overrides["output"] = Dict{String, Any}()
            end
            overrides["output"]["mode"] = val
        elseif startswith(arg, "--duration=")
            val = parse(Float64, split(arg, "=")[2])
            if !haskey(overrides, "simulation")
                overrides["simulation"] = Dict{String, Any}()
            end
            overrides["simulation"]["duration"] = val
        elseif startswith(arg, "--N=")
            val = parse(Int, split(arg, "=")[2])
            if !haskey(overrides, "simulation")
                overrides["simulation"] = Dict{String, Any}()
            end
            if !haskey(overrides["simulation"], "params")
                overrides["simulation"]["params"] = Dict{String, Any}()
            end
            overrides["simulation"]["params"]["N"] = val
        elseif startswith(arg, "--help") || arg == "-h"
            print_help()
            exit(0)
        elseif !startswith(arg, "-") && i == 1 # First arg can be config file if not flagged
             config_file = arg
        else
            println("Unknown argument: $arg")
        end
        i += 1
    end

    return config_file, overrides
end

function print_help()
    println("Usage: julia sim.jl [config_file] [options]")
    println("Options:")
    println("  --config, -c <file>   Specify configuration file (default: config.json)")
    println("  --mode=<mode>         Override output mode (interactive, render, export)")
    println("  --duration=<sec>      Override simulation duration")
    println("  --N=<count>           Override particle count")
    println("  --help, -h            Show this help message")
end

end
