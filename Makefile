# BallSim Makefile

.PHONY: run run-render run-export run-interactive test lint format setup clean

# Default runs render (headless)
run: run-render

run-render:
	julia --project=. sim.jl config.yaml --mode render

run-export:
	julia --project=. sim.jl config.yaml --mode export

run-interactive:
	julia --project=. -e 'using Pkg; Pkg.add("GLMakie"); using GLMakie'
	julia --project=. sim.jl config.yaml --mode interactive

test:
	julia --project=. -e 'using Pkg; Pkg.test()'

lint:
	julia --project=tools/maintenance -e 'using Pkg; Pkg.instantiate(); include("../lint.jl")'

format:
	julia --project=tools/maintenance -e 'using Pkg; Pkg.instantiate(); include("../format.jl")'

setup:
	./setup.sh

clean:
	rm -rf sandbox/
