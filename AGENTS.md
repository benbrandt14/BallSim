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
*   **Configuration:** Use `config.json` and `src/Config.jl` for simulation parameters.
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
