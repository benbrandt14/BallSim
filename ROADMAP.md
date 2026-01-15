# BallSim Roadmap

This document outlines the strategic direction for `BallSim.jl`. It serves as a guide for contributors and agents working on the project.

## 1. Physics Engine Enhancements

### Solvers
*   **Symplectic Integration**: Implement symplectic integrators (e.g., Velocity Verlet, Leapfrog, Forest-Ruth) to better conserve energy in long-running simulations.
    *   *Research*: See Störmer-Verlet methods and their properties for Hamiltonian systems.
*   **Rigid Body Dynamics**: Extend particle physics to support rigid bodies with rotational dynamics (quaternions, inertia tensors).
*   **Constraints**: Add support for distance joints, hinges, and springs between particles.

### Collision Detection
*   **Spatial Partitioning**: Implement broad-phase algorithms to reduce collision checks from $O(N^2)$ to $O(N \log N)$ or $O(N)$.
    *   **Spatial Hashing**: Efficient for uniform particle distributions.
    *   **Quadtrees (2D) / Octrees (3D)**: Adaptive spatial subdivision.
    *   **Verlet Lists**: Maintain neighbor lists to minimize distance checks.

### Field Specifications
*   **Field Composition**: Enhance the `CombinedField` to allow more complex, non-linear combinations of fields.
*   **Time-Varying Fields**: Standardize interface for fields that change properties over time (e.g., pulsing gravity).

## 2. High-Performance Computing (HPC)

### GPU Acceleration
*   **KernelAbstractions.jl**: Refactor core physics loops (`Physics.step!`, `detect_collision`) into kernels using `KernelAbstractions.jl`.
    *   *Goal*: Enable single-codebase execution on CPU, CUDA (NVIDIA), AMDGPU, and Metal (Apple Silicon).
*   **Memory Management**: Optimize data transfer between host and device; utilize GPU-specific memory hierarchies (shared memory) where applicable.

### Parallelism
*   **Task-Based Parallelism**: Explore `Julia`'s `Threads.@spawn` for more granular task scheduling beyond the current `Threads.@threads` loop.

## 3. Visualization & Analytics

### Phase Space Exploration
*   **Phase Plots**: Implement tools to visualize Momentum ($p$) vs Position ($q$) to analyze system stability and chaos.
*   **Poincaré Sections**: Tools for slicing high-dimensional phase space.

### 3D Visualization
*   **Volumetric Rendering**: Use `Makie.jl`'s volume rendering capabilities for density fields.
*   **Interactive Camera**: Enhance `BallSimInteractiveExt` with better 3D camera controls (orbit, pan, zoom).

### In-Situ Analytics
*   **Conservation Checks**: Real-time monitoring of Total Energy ($E = T + V$) and Linear/Angular Momentum to detect drift.
*   **Virial Theorem**: Verify system equilibrium states using the Virial Theorem ($2\langle T \rangle = -\langle \sum \mathbf{F}_k \cdot \mathbf{r}_k \rangle$).

## 4. Infrastructure & Developer Experience

### Logging & Diagnostics
*   **Structured Logging**: Implement a logging system (using `LoggingExtras.jl` or similar) to capture simulation events, errors, and performance metrics.
*   **Diagnostic Reports**: Tools to dump full system state (config + binary snapshot) on crash or divergence.

### Inspiration & Related Projects
*   **Project Chrono**: Open-source physics engine (reference for constraints/rigid bodies).
*   **Molly.jl**: Molecular dynamics in Julia (reference for integrators and potentials).
*   **Makie.jl**: Reference for advanced visualization recipes.
