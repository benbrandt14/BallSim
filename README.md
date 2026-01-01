# BallSim: Physics Playground for Balls

**Status:** Freshly Vibed Trash | **Core:** Julia 1.10+ | **Rendering:** Makie

BallSim is some vibecoded shit built in Julia. It pretends to look at **energy conservation**, **continuous collision detection (CCD)**. 
It is "designed" to simulate large particle counts ($N > 100k$) with sub-millimeter precision, with plots to look more closely at errors like "tunneling" or "energy drift" resulting from numerical inaccuracy.

<img width="1562" height="1514" alt="image" src="https://github.com/user-attachments/assets/335fab92-36f8-40ad-9b98-db4e8cda0d6d" />

## Quick Start

### 1. Installation
Initialize the local environment and register the package in development mode.

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.develop(path=".")'

```

## Running the Simulation

### Option 1: The Wrapper Script (Recommended)
We provide a convenience script `sim.jl` in the root directory.

```bash
# Run with defaults
./sim.jl

# Run with custom settings
./sim.jl --duration 10 --fps 30 --out my_video.mp4
```

| Argument | Description | Default |
| --- | --- | --- |
| `--duration` | Length of simulation in seconds | `5.0` |
| `--fps` | Framerate of the output video | `60` |
| `--out` | Output file path | `sandbox/sim_TIMESTAMP.mp4` |

### 3. Interactive Debugging

Opens a graphical dashboard to visually profile solver accuracy, wall penetration, and energy distribution.

```bash
julia --project=. experiments/diagnostics.jl

```

*Menu Options include: Bounce Accuracy, Wall Microscope, Penetration Stress Test, and Performance Profiling.*

### 4. Running the Test Suite

Runs the full battery of Unit, Visual, Benchmark, and Regression tests.

```bash
julia --project=. test/runtests.jl

```

---

## System Architecture & Design Intent

This section documents the purpose of each file to assist AI agents and developers in extending the system.

### Source (`src/`)

| File | Design Intent |
| --- | --- |
| **`BallSim.jl`** | **The Package Hub.** Exports modules and contains the high-level `run_demo()` entry point and CLI argument parser. |
| **`Common.jl`** | **The Contract.** Defines the core data structures (`BallSystem`, `Particle`) and abstract interfaces (`AbstractBoundary`, `AbstractSolver`). It is the only file that other modules are allowed to depend on circular-dependency-free. |
| **`Shapes.jl`** | **The Geometry.** Implements `AbstractBoundary` using **Signed Distance Functions (SDF)**. <br>

<br> *Key Concept:* All shapes must define `sdf(b, p, t)` (return distance to surface) and `normal(b, p, t)`. |
| **`Physics.jl`** | **The Engine.** Implements integration and collision resolution. <br>

<br> *Current Solvers:* <br>

<br> • `DiscreteSolver`: Symplectic Euler. Fast, good for dust/fluids. <br>

<br> • `CCDSolver`: Continuous Collision Detection. Uses sub-stepping and second-order integration to prevent tunneling and energy drift. |

### Experiments (`experiments/`)

| File | Design Intent |
| --- | --- |
| **`diagnostics.jl`** | **Interactive Profiler.** A standalone Makie application for debugging physics artifacts. It compares solver output against analytical ground truth (parabolic equations) to visualize residuals. |

### Tests (`test/`)

The test suite is tiered to catch different classes of failures.

| File | Design Intent |
| --- | --- |
| **`runtests.jl`** | **The Orchestrator.** Runs all test modules in isolated processes to prevent namespace pollution. |
| **`fixtures.jl`** | **Shared Tooling.** Provides ASCII visualization tools (`print_sdf_slice`) and the `compare_solvers` benchmarking logic used by other tests. |
| **`test_shapes.jl`** | **Geometry Unit Tests.** Verifies that SDFs and gradients are mathematically consistent (e.g., normal vectors point the right way). |
| **`test_physics.jl`** | **Logic Unit Tests.** Verifies single-particle behaviors like Energy Conservation (Vacuum Test) and Tunneling Prevention (High-Velocity Wall Test). |
| **`test_benchmarks.jl`** | **Performance Stress Test.** Runs the "Pressure Cooker" scenario (1000 fast particles in a small box) to assert that high-performance solvers do not leak particles. |
| **`test_regression.jl`** | **Golden Master Testing.** Compares the current simulation state (energy, center of mass) against a saved binary fingerprint (`regression_data/`). |

---

## Workflows

### Updating the Regression Baseline

If you make a change to the physics engine (e.g., changing Gravity from 9.81 to 10.0) that causes the regression test to fail *intentionally*, you must "bless" the new result:

```bash
UPDATE_REGRESSION=1 julia --project=. test/runtests.jl

```

### Adding a New Shape

1. Define the struct in `src/Shapes.jl`.
2. Implement `Common.sdf` and `Common.normal`.
3. Add a visual check in `test/test_shapes.jl` using `TestFixtures.print_sdf_slice`.
4. Run `julia --project=. test/test_shapes.jl` to verify.

### Adding a New Solver

1. Define the struct in `src/Physics.jl` inheriting from `AbstractSolver`.
2. Implement `Physics.step!`.
3. Add the new solver to the dictionary in `test/test_benchmarks.jl`.
4. Run `experiments/diagnostics.jl` and select your new solver to profile it visually.

```bash
julia --project=. test/runtests.jl

```

---

## System Architecture & Design Intent

This section documents the purpose of each file to assist AI agents and developers in extending the system.

### Source (`src/`)

| File | Design Intent |
| --- | --- |
| **`BallSim.jl`** | **The Package Hub.** Exports modules and contains the high-level `run_demo()` entry point. Serves as the root for the Language Server. |
| **`Common.jl`** | **The Contract.** Defines the core data structures (`BallSystem`, `Particle`) and abstract interfaces (`AbstractBoundary`, `AbstractSolver`). It is the only file that other modules are allowed to depend on circular-dependency-free. |
| **`Shapes.jl`** | **The Geometry.** Implements `AbstractBoundary` using **Signed Distance Functions (SDF)**. <br>

<br> *Key Concept:* All shapes must define `sdf(b, p, t)` (return distance to surface) and `normal(b, p, t)`. |
| **`Physics.jl`** | **The Engine.** Implements integration and collision resolution. <br>

<br> *Current Solvers:* <br>

<br> • `DiscreteSolver`: Symplectic Euler. Fast, good for dust/fluids. <br>

<br> • `CCDSolver`: Continuous Collision Detection. Uses sub-stepping and second-order integration to prevent tunneling and energy drift. |

### Experiments (`experiments/`)

| File | Design Intent |
| --- | --- |
| **`diagnostics.jl`** | **Interactive Profiler.** A standalone Makie application for debugging physics artifacts. It compares solver output against analytical ground truth (parabolic equations) to visualize residuals. |

### Tests (`test/`)

The test suite is tiered to catch different classes of failures.

| File | Design Intent |
| --- | --- |
| **`runtests.jl`** | **The Orchestrator.** Runs all test modules in isolated processes to prevent namespace pollution. |
| **`fixtures.jl`** | **Shared Tooling.** Provides ASCII visualization tools (`print_sdf_slice`) and the `compare_solvers` benchmarking logic used by other tests. |
| **`test_shapes.jl`** | **Geometry Unit Tests.** Verifies that SDFs and gradients are mathematically consistent (e.g., normal vectors point the right way). |
| **`test_physics.jl`** | **Logic Unit Tests.** Verifies single-particle behaviors like Energy Conservation (Vacuum Test) and Tunneling Prevention (High-Velocity Wall Test). |
| **`test_benchmarks.jl`** | **Performance Stress Test.** Runs the "Pressure Cooker" scenario (1000 fast particles in a small box) to assert that high-performance solvers do not leak particles. |
| **`test_regression.jl`** | **Golden Master Testing.** Compares the current simulation state (energy, center of mass) against a saved binary fingerprint (`regression_data/`). |

---

## Workflows

### Updating the Regression Baseline

If you make a change to the physics engine (e.g., changing Gravity from 9.81 to 10.0) that causes the regression test to fail *intentionally*, you must "bless" the new result:

```bash
UPDATE_REGRESSION=1 julia --project=. test/runtests.jl

```

### Adding a New Shape

1. Define the struct in `src/Shapes.jl`.
2. Implement `Common.sdf` and `Common.normal`.
3. Add a visual check in `test/test_shapes.jl` using `TestFixtures.print_sdf_slice`.
4. Run `julia --project=. test/test_shapes.jl` to verify.

### Adding a New Solver

1. Define the struct in `src/Physics.jl` inheriting from `AbstractSolver`.
2. Implement `Physics.step!`.
3. Add the new solver to the dictionary in `test/test_benchmarks.jl`.
4. Run `experiments/diagnostics.jl` and select your new solver to profile it visually.
