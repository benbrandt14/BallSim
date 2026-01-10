# BallSim UI Configurator

This directory contains the web-based UI configurator for BallSim.

## Quick Start

1.  **Initialize the Environment (Run Once)**
    This step links the local `BallSim` package to the UI environment and installs dependencies.
    ```bash
    julia setup_ui.jl
    ```

2.  **Run the App**
    ```bash
    julia --project=. app.jl
    ```

3.  **Open in Browser**
    Navigate to `http://localhost:8000` (or the URL shown in the console).

## Files

*   `app.jl`: The main application entry point (Genie + Stipple).
*   `setup_ui.jl`: Helper script to set up the environment.
*   `Project.toml` / `Manifest.toml`: Environment definition for the UI tool (separate from the main project).
