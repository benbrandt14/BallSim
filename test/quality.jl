using Test
using BallSim
using Aqua

@testset "Project Quality" begin

    @testset "Aqua (Method Ambiguities & Stale Deps)" begin
        Aqua.test_all(
            BallSim;
            ambiguities = false,
            stale_deps = (ignore = [:GLMakie],),
            persistent_tasks = false,
        )
    end
end
