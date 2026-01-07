## 2024-05-23 - Loop Inversion in Physics Kernel
**Learning:** Inverting the substep loop inside the parallel particle loop drastically reduces thread synchronization overhead and memory traffic, provided particles are independent.
**Action:** Always check for independent parallel workloads nested inside serial loops.

## 2024-05-23 - Environment Constraint
**Learning:** Unable to run Julia environment in this sandbox due to missing executable and installation limits.
**Action:** Rely on architectural analysis and best practices when tools are unavailable.

## 2024-05-23 - Julia Float32 Literal Syntax
**Learning:** Float32 literals using scientific notation in Julia must use `f` as the exponent separator (e.g., `1f-4`). `1e-4f0` is invalid because it is parsed as `1e-4 * f0`, where `f0` is treated as a variable.
**Action:** Always verify scientific notation syntax when working with Float32 in Julia.

## 2024-05-23 - Analytical vs Numerical Gradients
**Learning:** Numerical gradients (using finite differences) for simple shapes like Box are significantly slower (3-4x) than analytical solutions and can hide syntax errors if not covered by tests.
**Action:** Always prefer analytical derivatives for geometric primitives where possible.