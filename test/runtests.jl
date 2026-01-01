using Test
using BallSim

# Helper to run scripts safely
function run_test_script(path)
    file_name = basename(path)
    printstyled("\n[RUNNING] $file_name ...\n", color=:cyan, bold=true)
    cmd = `$(Base.julia_cmd()) --project=. $path`
    if haskey(ENV, "UPDATE_REGRESSION")
        cmd = addenv(cmd, "UPDATE_REGRESSION" => ENV["UPDATE_REGRESSION"])
    end
    try
        run(cmd)
        printstyled("[PASSED] $file_name\n", color=:green, bold=true)
        return true
    catch
        printstyled("[FAILED] $file_name\n", color=:red, bold=true)
        return false
    end
end

@testset "BallSim Full Suite" begin
    @test run_test_script("test/test_shapes.jl")
    @test run_test_script("test/test_physics.jl")
    @test run_test_script("test/test_benchmarks.jl")
    @test run_test_script("test/test_regression.jl")
end
