.PHONY: test run lint clean install format

install:
	julia --project=. -e 'using Pkg; Pkg.instantiate()'

test:
	julia --project=. -e 'using Pkg; Pkg.test()'

run:
	julia --project=. -e 'using Pkg; Pkg.activate(); include("src/main.jl")'

lint:
	echo "I don't have linting configured yet."

format:
	julia --project=. -e 'using JuliaFormatter; format(".")'

clean:
	echo "I don't have any cleaning steps yet."
