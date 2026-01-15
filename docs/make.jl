using BallSim
using Documenter

DocMeta.setdocmeta!(BallSim, :DocTestSetup, :(using BallSim); recursive = true)

makedocs(;
    modules = [BallSim],
    authors = "Ben Brandt <benbrandt14@gmail.com> and contributors",
    sitename = "BallSim.jl",
    format = Documenter.HTML(;
        canonical = "https://benbrandt14.github.io/BallSim.jl/stable",
        edit_link = "main",
        assets = String[],
    ),
    pages = ["Home" => "index.md"],
    warnonly = true,
)

deploydocs(; repo = "github.com/benbrandt14/BallSim.jl", devbranch = "main")
