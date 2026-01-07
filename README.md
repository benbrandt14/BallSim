# BallSim: Physics Playground for Balls
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

**Status:** Freshly Vibed Trash | **Core:** Julia 1.10+ | **Rendering:** Makie

<img width="1562" height="1514" alt="image" src="https://github.com/user-attachments/assets/335fab92-36f8-40ad-9b98-db4e8cda0d6d" />

# BallSim.jl

A high-performance, multi-threaded 2D and 3D physics engine written in Julia. Designed for massive particle simulations ($N > 10^6$) with a decoupled rendering pipeline capable of 8K visualizations.

Inspired by [the work of Alexander Gustafsson](https://www.youtube.com/watch?v=VJn2cHscTUM)

## Features

* **Performance:** Structure-of-Arrays (SoA) data layout with multi-threaded physics kernels.
* **Modular Architecture:** Physics, Geometry, and Rendering are strictly decoupled.
* **Declarative Configuration:** Full simulation control via JSON files (solvers, fields, boundaries).
* **"Darkroom" Rendering:** Headless HDF5 export pipeline with a separate high-res rendering tool (supports Logarithmic Tone Mapping).
* **Extensible:** Easy interfaces for defining new Shapes, Force Fields, and Scenarios.

## Installation

```bash
git clone [https://github.com/benbrandt14/BallSim](https://github.com/benbrandt14/BallSim)
cd BallSim
# Option 1: Quick Start (Installs Julia if needed, instantiates, and tests)
./setup.sh

# Option 2: Manual Setup
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Usage

**Configuration Structure (`config.json`):**

```json
{
    "simulation": {
        "type": "Spiral", // Extendable via Scenarios.jl
        "params": { "N": 50000 },
        "duration": 10.0,
        "dimensions": 3  // Optional: 2 (default) or 3
    },
    "physics": {
        "dt": 0.002,
        "solver": "CCD",
        "solver_params": {
            "restitution": 0.5, // 1.0 = Bouncy, 0.0 = Sticky
            "substeps": 8       // Higher = More precise collision
        },
        "gravity": {
            "type": "Central",  // Options: "Central", "Uniform", "Zero"
            "params": {
                "strength": 20.0,
                "mode": "attractor",
                "center": [0.0, 0.0, 0.0] // 3D Center if dimensions=3
            }
        },
        "boundary": {
            "type": "Circle", // Options: "Circle" (2D/3D), "Box" (2D), "Ellipsoid" (2D), "InvertedCircle"
            "params": {
                "radius": 1.0
            }
        }
    },
    "output": {
        "mode": "render", // "interactive" (GLMakie), "render", "export"
        "res": 800,
        "fps": 60,
        "filename": "sandbox/simulation",
        "projection": "xy" // Optional for 3D: "xy" (default), "xz", "yz", or custom { "u": [1,0,0], "v": [0,0,1] }
    }
}
```

### 2. The Darkroom (High-Res Visualization)

Turn raw HDF5 data into art using the standalone renderer tool.

```bash
# Usage: julia tools/render_frame.jl <h5_file> <frame_index>
julia --project=. tools/render_frame.jl sandbox/data_123456.h5 10

```

* **Output:** A 4K (3840x2160) PNG with logarithmic tone mapping.
* **Performance:** Multi-threaded accumulation buffer; renders 1M particles in milliseconds.

## Extension Guide

BallSim is built on a "Plugin" architecture. You can extend it without modifying the core loop.

### 1. Adding a New Scenario

Create a struct that subtypes `Common.AbstractScenario{D}`.

```julia
# src/Scenarios.jl

struct GalaxyScenario <: Common.AbstractScenario{2}
    N::Int
end

# A. Define Initial Conditions
function Scenarios.initialize!(sys::Common.BallSystem{2, T, S}, scen::GalaxyScenario) where {T, S}
    # Initialize sys.data.pos and sys.data.vel here...
end

# B. Define Physics Rules (Solver Config)
function Common.get_default_solver(scen::GalaxyScenario)
    return Physics.CCDSolver(0.001f0, 1.0f0, 8)
end

# C. Define Forces
function Common.get_force_field(scen::GalaxyScenario)
    # Combine Gravity and Drag
    g = Fields.CentralField(SVector(0f0, 0f0), 100.0f0)
    d = Fields.ViscousDrag(0.1f0)
    return Fields.CombinedField((g, d))
end

```

### 2. Adding a New Shape

Create a struct that subtypes `Common.AbstractBoundary{D}`.

```julia
# src/Shapes.jl

struct Triangle <: Common.AbstractBoundary{2}
    p1::SVector{2, Float32}
    p2::SVector{2, Float32}
    p3::SVector{2, Float32}
end

# A. Signed Distance Function
function Common.sdf(b::Triangle, p::SVector{2}, t)
    # Return distance (Negative = Inside, Positive = Outside)
end

# B. Normal Vector
function Common.normal(b::Triangle, p::SVector{2}, t)
    # Return normalized vector pointing OUT of the shape
end

```

### 3. Adding a New Force Field

Create a struct that subtypes `Fields.AbstractField`.

```julia
# src/Fields.jl

struct MagneticField <: Fields.AbstractField
    strength::Float32
end

# Implement the Functor
function (f::MagneticField)(p, v, t)
    # Return Force Vector F = q(v x B) ...
    return SVector(...) 
end

```

## Testing

I told Gemini to use a TDD workflow.

* **Unit Tests:** `julia --project=. -e 'using Pkg; Pkg.test()'`
* **Hygiene:** `Aqua.jl` ensures no method ambiguities or stale dependencies.

## Project Structure

```text
src/
├── BallSim.jl       # Main entry point & dependency loader
├── Common.jl        # Core Types (BallSystem) & Interfaces
├── Config.jl        # JSON Configuration Factory
├── Physics.jl       # Solvers (CCDSolver) & Integration Kernels
├── Shapes.jl        # Geometry (SDFs for Circle, Box, Ellipsoid)
├── Fields.jl        # Force Fields (Gravity, Drag, Central)
├── Scenarios.jl     # Recipes (Spiral, Galaxy, etc.)
├── Vis.jl           # Real-time Visualization logic
└── SimIO.jl         # HDF5 Input/Output

tools/
└── render_frame.jl  # Standalone High-Res Renderer

```