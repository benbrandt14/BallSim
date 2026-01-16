using BallSim
using StaticArrays
using BenchmarkTools
using BallSim.Common
using BallSim.Shapes

function benchmark_box()
    b = Shapes.Box(10.0f0, 10.0f0)
    p = SVector(5.1f0, 4.0f0) # Outside x
    t = 0.0f0

    # Warmup
    Common.detect_collision(b, p, t)

    println("Benchmarking Box collision...")
    @btime Common.detect_collision($b, $p, $t)
end

function benchmark_box3d()
    b = Shapes.Box3D(10.0f0, 10.0f0, 10.0f0)
    p = SVector(5.1f0, 4.0f0, 1.0f0)
    t = 0.0f0

    Common.detect_collision(b, p, t)

    println("Benchmarking Box3D collision...")
    @btime Common.detect_collision($b, $p, $t)
end

benchmark_box()
benchmark_box3d()
