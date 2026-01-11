using Test
using BallSim
using BallSim.Config

@testset "Config Validation Tests" begin
    @testset "validate_positive" begin
        @test Config.validate_positive(10, "test") == 10
        @test_throws ErrorException Config.validate_positive(0, "test")
        @test_throws ErrorException Config.validate_positive(-5, "test")
    end

    @testset "validate_choice" begin
        @test Config.validate_choice(:a, [:a, :b], "test") == :a
        @test_throws ErrorException Config.validate_choice(:c, [:a, :b], "test")
    end

    @testset "validate_boundary_params" begin
        # Circle (valid)
        Config.validate_boundary_params(:Circle, Dict(:radius => 10.0), 2)
        # Circle (invalid)
        @test_throws ErrorException Config.validate_boundary_params(:Circle, Dict(), 2)
        @test_throws ErrorException Config.validate_boundary_params(:Circle, Dict(:radius => -1.0), 2)

        # Box 2D (valid)
        Config.validate_boundary_params(:Box, Dict(:width => 10, :height => 10), 2)
        # Box 2D (invalid)
        @test_throws ErrorException Config.validate_boundary_params(:Box, Dict(:width => 10), 2)

        # Box 3D (valid)
        Config.validate_boundary_params(:Box, Dict(:width => 10, :height => 10, :depth => 10), 3)
        # Box 3D (invalid - missing depth)
        @test_throws ErrorException Config.validate_boundary_params(:Box, Dict(:width => 10, :height => 10), 3)
    end

    @testset "validate_gravity_params" begin
        # Uniform (valid)
        Config.validate_gravity_params(:Uniform, Dict(:vector => [0, -9.8]), 2)
        # Uniform (invalid dims)
        @test_throws ErrorException Config.validate_gravity_params(:Uniform, Dict(:vector => [0, -9.8, 0]), 2)
        # Uniform (missing vector)
         @test_throws ErrorException Config.validate_gravity_params(:Uniform, Dict(), 2)

        # Central (valid)
        Config.validate_gravity_params(:Central, Dict(:strength => 100), 2)
        # Central (missing strength)
        @test_throws ErrorException Config.validate_gravity_params(:Central, Dict(), 2)
    end
end
