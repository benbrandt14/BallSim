#!/bin/bash
set -e

# Setup script for BallSim.jl

# 1. Check for Julia
if ! command -v julia &> /dev/null; then
    echo "Julia not found. Installing local version to /tmp..."

    # Define Julia version
    JULIA_VER="1.10.4"
    JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-${JULIA_VER}-linux-x86_64.tar.gz"
    INSTALL_DIR="/tmp/julia_bin"

    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
        echo "Downloading Julia ${JULIA_VER}..."
        curl -L "$JULIA_URL" | tar -xz -C "$INSTALL_DIR" --strip-components=1
    else
        echo "Julia already installed in $INSTALL_DIR"
    fi

    export PATH="$INSTALL_DIR/bin:$PATH"
    echo "Added to PATH for this session."
else
    echo "Julia found at $(which julia)"
fi

echo "Julia Version:"
julia --version

# 2. Instantiate Project
echo "Instantiating project..."
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# 3. Run Tests
echo "Running tests..."
julia --project=. -e 'using Pkg; Pkg.test()'

echo "Setup complete!"
