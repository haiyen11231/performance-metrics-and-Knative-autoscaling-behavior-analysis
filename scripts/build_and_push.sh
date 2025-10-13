#!/bin/bash
set -e

echo "Building Docker images..."
# Build both images in parallel
make build &

# Wait for both builds to finish
wait
echo "Docker builds completed."

echo "Pushing Docker images..."
make push &

wait
echo "Docker push completed."