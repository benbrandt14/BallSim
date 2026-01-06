# Debug Scripts

This directory contains scripts to verify and profile the BallSim physics engine.

## Usage

Run these scripts from the root of the repository using Julia:

```bash
julia debug_scripts/verify_analytical.jl
julia debug_scripts/profile_perf.jl
julia debug_scripts/check_energy.jl
```

## Scripts

### 1. `verify_analytical.jl`
Verifies the physics solver against analytical solutions.
- **Wall Bounce:** Checks if a particle bounces off a wall and returns to the expected position.
- **Gravity Drop:** Checks if a particle falls under gravity, bounces, and returns.
- **Tunneling:** Checks if a high-speed particle tunnels through a thin boundary (testing CCD logic).

### 2. `profile_perf.jl`
Benchmarks the runtime performance of the simulation with a large number of particles.
- Reports Duration, FPS, and Particle Updates per Second.

### 3. `check_energy.jl`
Evaluates energy conservation in a closed system.
- Tracks Kinetic and Potential energy over time to quantify numerical drift (integration error).
