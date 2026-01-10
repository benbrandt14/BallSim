using Test
using JSON3
using StaticArrays
using BallSim
using BallSim.Common
using BallSim.Shapes
using BallSim.Fields
using BallSim.Config

@testset "Configuration System" begin
    
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
            @test cfg.scenario_params[:N] == 100
            @test cfg.duration == 1.0
            @test cfg.dt == 0.01f0
            @test cfg.solver == :CCD
            @test cfg.boundary_type == :Circle
        end
    end

    @testset "Boundary Factory" begin
        c_circle = deepcopy(base_config)
        c_circle[:physics][:boundary] = Dict(:type => "Circle", :params => Dict(:radius => 5.0))
        with_config(c_circle) do path
            cfg = Config.load_config(path)
            b = Config.create_boundary(cfg)
            @test b isa Shapes.Circle
            @test b.radius == 5.0f0
        end

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
        c_uni = deepcopy(base_config)
        c_uni[:physics][:gravity] = Dict(:type => "Uniform", :params => Dict(:vector => [0.0, -9.8]))
        with_config(c_uni) do path
            cfg = Config.load_config(path)
            g = Config.create_gravity(cfg)
            @test g isa Fields.UniformField
            @test g.vector ≈ SVector(0.0f0, -9.8f0)
        end
    end

    @testset "Sanitation" begin
        # 1. Invalid Mode
        c_bad_mode = deepcopy(base_config)
        c_bad_mode[:output][:mode] = "telepathic"
        with_config(c_bad_mode) do path
            @test_throws ErrorException Config.load_config(path)
        end

        # 2. Negative Radius
        c_neg_rad = deepcopy(base_config)
        c_neg_rad[:physics][:boundary][:params][:radius] = -5.0
        with_config(c_neg_rad) do path
            @test_throws ErrorException Config.load_config(path)
        end
        
        # 3. Missing Required Param
        c_missing = deepcopy(base_config)
        delete!(c_missing[:physics][:boundary][:params], :radius)
        with_config(c_missing) do path
            @test_throws ErrorException Config.load_config(path)
        end

        # 4. 3D Box missing Depth
        c_box3d = deepcopy(base_config)
        c_box3d[:simulation][:dimensions] = 3
        c_box3d[:physics][:boundary] = Dict(:type => "Box", :params => Dict(:width => 10.0, :height => 10.0))
        # Missing depth
        with_config(c_box3d) do path
             @test_throws ErrorException Config.load_config(path)
        end

        # 5. Invalid Gravity Vector Length
        c_grav = deepcopy(base_config)
        c_grav[:physics][:gravity] = Dict(:type => "Uniform", :params => Dict(:vector => [0.0, -9.8, 1.0])) # 3 components
        c_grav[:simulation][:dimensions] = 2 # but 2D sim
        with_config(c_grav) do path
            @test_throws ErrorException Config.load_config(path)
        end
    end
    
    @testset "Integration" begin
        c_run = deepcopy(base_config)
        output_path = tempname()
        c_run[:output][:filename] = output_path
        c_run[:simulation][:N] = 10
        c_run[:simulation][:duration] = 0.05
        
        with_config(c_run) do path
            BallSim.run_simulation(path)
            expected_file = output_path * ".h5"
            @test isfile(expected_file)
            rm(expected_file, force=true)
        end
    end
end