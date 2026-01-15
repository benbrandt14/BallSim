# BallSim Makefile

.PHONY: update run run-render run-export run-interactive test lint format setup clean

# Default runs render (headless)
run: run-render

run-render:
	julia --project=. sim.jl config.yaml --mode render

run-export:
	julia --project=. sim.jl config.yaml --mode export

run-interactive:
	julia --project=. -e 'using Pkg; Pkg.add("GLMakie"); using GLMakie'
	julia --project=. sim.jl config.yaml --mode interactive

update:
	julia --project=. -e 'using Pkg; Pkg.resolve()'

test:
	julia --project=. -e 'using Pkg; Pkg.test()'

doctest:
	julia --project=docs/ -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate(); using Documenter: DocMeta, doctest; using BallSim; DocMeta.setdocmeta!(BallSim, :DocTestSetup, :(using BallSim, StaticArrays); recursive=true); doctest(BallSim)'

lint:
	julia --project=tools/maintenance -e 'using Pkg; Pkg.instantiate(); include("../lint.jl")'

format:
	julia --project=tools/maintenance -e 'using Pkg; Pkg.instantiate(); include("../format.jl")'

setup:
	./setup.sh

clean:
	rm -rf sandbox/
