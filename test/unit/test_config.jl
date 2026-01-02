using Test
using JSON3
using StaticArrays
using BallSim
using BallSim.Common
using BallSim.Shapes
using BallSim.Fields
using BallSim.Config

@testset "Configuration System" begin
    
    # Helper to create a temp config file for testing
    function with_config(f::Function, dict::Dict)
        path = tempname() * ".json"
        open(path, "w") do io
            JSON3.write(io, dict)
        end
        try
            f(path)
        finally
            rm(path, force=true)
        end
    end

    # Base valid config dictionary
    base_config = Dict(
        :simulation => Dict(:N => 100, :duration => 1.0),
        :physics => Dict(
            :dt => 0.01,
            :solver => "CCD",
            :gravity => Dict(:type => "Zero", :params => Dict()),
            :boundary => Dict(:type => "Circle", :params => Dict(:radius => 10.0))
        ),
        :output => Dict(
            :mode => "export",
            :filename => "test_out",
            :res => 400,
            :fps => 30
        )
    )

    @testset "Loader & Schema" begin
        with_config(base_config) do path
            cfg = Config.load_config(path)
            @test cfg.N == 100
            @test cfg.duration == 1.0
            @test cfg.dt == 0.01f0
            @test cfg.solver == :CCD
            @test cfg.boundary_type == :Circle
        end
    end

    @testset "Boundary Factory" begin
        # 1. Circle
        c_circle = deepcopy(base_config)
        c_circle[:physics][:boundary] = Dict(:type => "Circle", :params => Dict(:radius => 5.0))
        
        with_config(c_circle) do path
            cfg = Config.load_config(path)
            b = Config.create_boundary(cfg)
            @test b isa Shapes.Circle
            @test b.radius == 5.0f0
        end

        # 2. Inverted Ellipsoid (Complex case)
        # Note: Inverted is a wrapper, usually requires two-step factory if generic. 
        # Our current factory has explicit support for :InvertedCircle only in create_boundary.
        # Let's test that specific path.
        c_inv = deepcopy(base_config)
        c_inv[:physics][:boundary] = Dict(:type => "InvertedCircle", :params => Dict(:radius => 20.0))
        
        with_config(c_inv) do path
            cfg = Config.load_config(path)
            b = Config.create_boundary(cfg)
            @test b isa Shapes.Inverted{2, Shapes.Circle}
            @test b.inner.radius == 20.0f0
        end
    end

    @testset "Field Factory" begin
        # 1. Uniform
        c_uni = deepcopy(base_config)
        c_uni[:physics][:gravity] = Dict(
            :type => "Uniform", 
            :params => Dict(:vector => [0.0, -9.8])
        )
        
        with_config(c_uni) do path
            cfg = Config.load_config(path)
            g = Config.create_gravity(cfg)
            @test g isa Fields.UniformField
            @test g.vector ≈ SVector(0.0f0, -9.8f0)
        end

        # 2. Central
        c_cen = deepcopy(base_config)
        c_cen[:physics][:gravity] = Dict(
            :type => "Central", 
            :params => Dict(:center => [1.0, 1.0], :strength => 50.0, :mode => "repulsor")
        )
        
        with_config(c_cen) do path
            cfg = Config.load_config(path)
            g = Config.create_gravity(cfg)
            @test g isa Fields.CentralField
            @test g.center ≈ SVector(1.0f0, 1.0f0)
            @test g.strength == 50.0f0
        end
    end

    @testset "Integration" begin
        # Run a full mini-simulation via config
        c_run = deepcopy(base_config)
        output_path = tempname()
        c_run[:output][:filename] = output_path
        c_run[:simulation][:N] = 10 # Tiny N for speed
        c_run[:simulation][:duration] = 0.05 # Short duration
        
        with_config(c_run) do path
            # Execute the main driver entry point
            BallSim.run_simulation(path)
            
            # Verify output exists
            expected_file = output_path * ".h5"
            @test isfile(expected_file)
            rm(expected_file, force=true)
        end
    end
end