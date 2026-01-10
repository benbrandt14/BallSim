using Test
using Pkg
using SHA

"""
    generate_agent_debug_info()

Generates a diagnostic string containing environment information useful for AI agents debugging the system.
Includes:
- Julia Version
- Package Dependencies & Status
- Hashes of critical files (src/Physics.jl, src/Common.jl)
- Current Working Directory
"""
function generate_agent_debug_info()
    io = IOBuffer()
    println(io, "=== Agent Debug Info ===")
    println(io, "Julia Version: ", VERSION)
    println(io, "CWD: ", pwd())

    println(io, "\n--- Git Status ---")
    try
        # Simple check if git is available
        println(io, read(`git status --short`, String))
    catch
        println(io, "Git not available or error running git status.")
    end

    println(io, "\n--- Project Status ---")
    try
        Pkg.status(io=io)
    catch e
        println(io, "Error checking Pkg status: $e")
    end

    println(io, "\n--- Critical File Hashes ---")
    files = ["src/Physics.jl", "src/Common.jl", "src/Shapes.jl", "Project.toml", "Manifest.toml"]
    for f in files
        if isfile(f)
            h = bytes2hex(open(sha256, f))
            println(io, "$f: $h")
        else
            println(io, "$f: MISSING")
        end
    end

    return String(take!(io))
end

@testset "Debug Tool" begin
    info = generate_agent_debug_info()
    @test !isempty(info)
    @test contains(info, "Agent Debug Info")
    @test contains(info, "Julia Version")
    @test contains(info, "src/Physics.jl")

    # We print it so the agent (me) can see it in the logs if needed,
    # and to fulfill the "return text for agents" requirement.
    println(info)
end
