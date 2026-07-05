#!/bin/sh
set -e

if ! command -v hermes >/dev/null 2>&1; then
    echo "Installing hermes CLI..."
    pip install --quiet hermes-agent
fi

echo "Hermes Ops is ready."

# Keep the container alive
exec tail -f /dev/null
