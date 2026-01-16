module BallSimCUDAExt

using BallSim
using CUDA

function __init__()
    BallSim.register_backend("cuda", CUDA.CuArray)
end

end
