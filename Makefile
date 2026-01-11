.PHONY: test run run-interactive run-render run-export app render lint format clean install setup-tools

install:
	julia --project=. -e 'using Pkg; Pkg.instantiate()'

test:
	julia --project=. -e 'using Pkg; Pkg.test()'

run: run-interactive

setup-interactive:
	julia tools/setup_interactive.jl

run-interactive:
	julia --project=tools/interactive sim.jl config.json --mode interactive

run-render:
	julia --project=. sim.jl config.json --mode render

run-export:
	julia --project=. sim.jl config.json --mode export

app:
	julia tools/ui/setup_ui.jl
	julia --project=tools/ui tools/ui/app.jl

render:
	julia --project=. tools/render_frame.jl

setup-tools:
	julia tools/setup_maintenance.jl

lint: setup-tools
	julia tools/lint.jl

format: setup-tools
	julia tools/format.jl

clean:
	echo "I don't have any cleaning steps yet."
