#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Create data directories if they don't exist
mkdir -p "./data-dir-testing/a/conduit"
mkdir -p "./data-dir-testing/a/ldk"
mkdir -p "./data-dir-testing/b/conduit"
mkdir -p "./data-dir-testing/b/ldk"

# Set up trap to handle cleanup on exit (whether success or failure)
cleanup() {
  echo "Cleaning up..."
  
  # Kill any processes started by the test
  pkill -f "conduit-daemon" || true
  pkill -f "conduit-cli" || true
  
  # Remove data directories
  rm -rf "./data-dir-testing"
  
  # Tear down Docker containers
  docker compose -f docker-compose-testing.yml down -v
}

# Run cleanup on script exit (normal or error)
trap cleanup EXIT

# Start the postgres and bitcoind containers
docker compose -f docker-compose-testing.yml up -d

# Build the entire workspace
cargo build

# Run the testing binary
cargo run -p conduit-testing 