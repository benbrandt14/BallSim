using Pkg
Pkg.activate(".")
using BallSim
using BallSim.Config
using YAML

function check_config(path="config.yaml")
    println("Checking configuration file: $path")
    if !isfile(path)
        println("❌ File not found!")
        return
    end

    try
        cfg = Config.load_config(path)
        println("✅ Configuration is VALID.")
        println("  Scenario: $(cfg.scenario_type)")
        println("  Dimensions: $(cfg.dimensions)D")
        println("  Particles: $(get(cfg.scenario_params, :N, "Unknown"))")
        println("  Output Mode: $(cfg.mode)")
    catch e
        println("❌ Configuration is INVALID.")
        println("Error: ")
        showerror(stdout, e)
        println("\n")
        println("Tip: Check 'src/Config.jl' for allowed parameters and types.")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) > 0
        check_config(ARGS[1])
    else
        check_config()
    end
end
