# AGENTS.md

## Project Context
**BallSim.jl** is a high-performance, multi-threaded 2D physics engine written in Julia. It uses a Structure-of-Arrays (SoA) data layout and decoupled rendering.

## Coding Standards

### Julia Style
*   **Performance:** Use type-stable code. Avoid dynamic dispatch in inner loops.
*   **Data Layout:** Stick to the SoA layout defined in `src/Common.jl` for particle data.
*   **Testing:** Use `Test` standard library. Ensure new features have unit tests.

### Architecture
*   **Decoupling:** Physics, Geometry, and Rendering are strictly decoupled.
*   **Configuration:** Use `config.yaml` and `src/Config.jl` for simulation parameters.
*   **Extensions:**
    *   Scenarios in `src/Scenarios.jl`
    *   Shapes in `src/Shapes.jl`
    *   Force Fields in `src/Fields.jl`

## Workflow

### Setup
Run `./setup.sh` to install dependencies and run tests.

### Running Tests
```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

### Debugging
If you need to debug the environment or verify file integrity (e.g. check for modification), run the debug tool test:
```bash
julia --project=. test/debug_tool.jl
```
This will print environment details, git status, and hashes of critical source files.

### Documentation & Doctests
We use `Documenter.jl` for documentation and `jldoctest` to ensure examples in docstrings stay up-to-date.

**Writing Doctests:**
Add a `jldoctest` block to your docstring. Ensure you define all necessary variables.
```julia
"""
    my_func(x)

Returns x + 1.

# Example
```jldoctest
julia> using BallSim
julia> my_func(1)
2
```
"""
function my_func(x) ...
```

**Running Doctests:**
You can run doctests locally to verify them before pushing:
```bash
julia --project=docs/ -e '
  using Pkg
  Pkg.develop(PackageSpec(path=pwd()))
  Pkg.instantiate()
  using Documenter: DocMeta, doctest
  using BallSim
  DocMeta.setdocmeta!(BallSim, :DocTestSetup, :(using BallSim, StaticArrays); recursive=true)
  doctest(BallSim)'
```

### Running the Simulation
```bash
julia --project=. sim.jl
```

### Adding Dependencies
When adding a new package:
```julia
using Pkg; Pkg.add("PackageName")
```
Ensure `Project.toml` and `Manifest.toml` are up to date and corect.

## Verification
*   **Always** run tests after making changes: `julia --project=. -e 'using Pkg; Pkg.test()'`
*   **Check for regressions** in performance or stability if modifying core physics loops.
