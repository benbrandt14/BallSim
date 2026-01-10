.PHONY: test run lint clean install format

install:
	julia --project=. -e 'using Pkg; Pkg.instantiate()'

test:
	julia --project=. -e 'using Pkg; Pkg.test()'

run:
	julia --project=. sim.jl my_config.json

app:
	julia tools/ui/setup_ui.jl
	julia --project=tools/ui tools/ui/app.jl

render:
	julia --project=. tools/render_frame.jl

lint:
	echo "I don't have linting configured yet."

format:
	echo "I don't have formatting configured yet."

clean:
	echo "I don't have any cleaning steps yet."
