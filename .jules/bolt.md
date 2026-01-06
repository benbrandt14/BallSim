## 2024-05-23 - Loop Inversion in Physics Kernel
**Learning:** Inverting the substep loop inside the parallel particle loop drastically reduces thread synchronization overhead and memory traffic, provided particles are independent.
**Action:** Always check for independent parallel workloads nested inside serial loops.

## 2024-05-23 - Environment Constraint
**Learning:** Unable to run Julia environment in this sandbox due to missing executable and installation limits.
**Action:** Rely on architectural analysis and best practices when tools are unavailable.
