using Test
using Pkg
using SHA
using YAML
using Dates

"""
    generate_agent_debug_info()

Generates a diagnostic string containing environment information useful for AI agents debugging the system.
Includes:
- Julia Version & Environment Variables
- Package Dependencies & Status
- Hashes of critical files
- Source File Listing
- Config Validation
- Recent Logs
"""
function generate_agent_debug_info()
    io = IOBuffer()
    println(io, "=== Agent Debug Info ===")
    println(io, "Timestamp: ", Dates.now())
    println(io, "Julia Version: ", VERSION)
    println(io, "CWD: ", pwd())
    println(io, "Threads: ", Threads.nthreads())

    println(io, "\n--- Environment Variables ---")
    env_vars = ["JULIA_NUM_THREADS", "JULIA_LOAD_PATH", "JULIA_DEPOT_PATH", "CUDA_VISIBLE_DEVICES", "PATH"]
    for var in env_vars
        if haskey(ENV, var)
            println(io, "$var: ", ENV[var])
        else
            println(io, "$var: (not set)")
        end
    end

    println(io, "\n--- Git Status ---")
    try
        # Simple check if git is available
        println(io, read(`git status --short`, String))
    catch
        println(io, "Git not available or error running git status.")
    end

    println(io, "\n--- Project Status ---")
    try
        Pkg.status(io = io)
    catch e
        println(io, "Error checking Pkg status: $e")
    end

    println(io, "\n--- Source File Listing ---")
    try
        for (root, dirs, files) in walkdir("src")
            for file in files
                path = joinpath(root, file)
                size = filesize(path)
                println(io, "$path ($size bytes)")
            end
        end
    catch e
        println(io, "Error listing files: $e")
    end

    println(io, "\n--- Critical File Hashes ---")
    files = [
        "src/Physics.jl",
        "src/Common.jl",
        "src/Shapes.jl",
        "Project.toml",
        "Manifest.toml",
    ]
    for f in files
        if isfile(f)
            h = bytes2hex(open(sha256, f))
            println(io, "$f: $h")
        else
            println(io, "$f: MISSING")
        end
    end

    println(io, "\n--- Config Check (config.yaml) ---")
    if isfile("config.yaml")
        try
            cfg = YAML.load_file("config.yaml")
            println(io, "config.yaml exists and parses successfully.")
            if haskey(cfg, "simulation") && haskey(cfg["simulation"], "type")
                println(io, "Scenario: ", cfg["simulation"]["type"])
            else
                println(io, "Warning: 'simulation.type' key missing.")
            end
        catch e
            println(io, "Error parsing config.yaml: $e")
        end
    else
        println(io, "config.yaml: MISSING")
    end

    println(io, "\n--- Recent Test Logs (test_output.log) ---")
    if isfile("test_output.log")
        try
            lines = readlines("test_output.log")
            n = length(lines)
            start_idx = max(1, n - 20)
            println(io, "Last $(n - start_idx + 1) lines:")
            for i in start_idx:n
                println(io, lines[i])
            end
        catch e
            println(io, "Error reading test_output.log: $e")
        end
    else
        println(io, "test_output.log: NOT FOUND")
    end

    return String(take!(io))
end

@testset "Debug Tool" begin
    info = generate_agent_debug_info()
    @test !isempty(info)
    @test contains(info, "Agent Debug Info")
    @test contains(info, "Julia Version")
    @test contains(info, "src/Physics.jl")
    @test contains(info, "Threads:")

    # We print it so the agent (me) can see it in the logs if needed,
    # and to fulfill the "return text for agents" requirement.
    println(info)
end
