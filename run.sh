#!/bin/bash
# Wrapper script to run BallSim.jl

# Ensure script fails on error
set -e

# Default args
ARGS="$@"

# Check for Julia
JULIA_CMD="julia"
if ! command -v julia &> /dev/null; then
    # Check for local install from setup.sh
    if [ -f "/tmp/julia_bin/bin/julia" ]; then
        JULIA_CMD="/tmp/julia_bin/bin/julia"
    else
        echo "Error: Julia is not installed or not in PATH."
        echo "Try running ./setup.sh first."
        exit 1
    fi
fi

# Run the simulation
echo "Running BallSim with args: $ARGS"
"$JULIA_CMD" --project=. sim.jl $ARGS
