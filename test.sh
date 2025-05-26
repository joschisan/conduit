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
  
  # Kill daemons started by the test
  pkill -f "conduit-daemon" || true
  
  # Remove data directories
  rm -rf "./data-dir-testing"
  
  # Stop and remove bitcoind container
  docker stop conduit-bitcoind || true
  docker rm conduit-bitcoind || true
}

# Run cleanup on script exit (normal or error)
trap cleanup EXIT

# Start bitcoind container
docker run -d \
  --name conduit-bitcoind \
  -p 18443:18443 \
  -p 18444:18444 \
  ruimarinho/bitcoin-core:latest \
  -regtest=1 \
  -server=1 \
  -rpcuser=bitcoin \
  -rpcpassword=bitcoin \
  -rpcallowip=0.0.0.0/0 \
  -rpcbind=0.0.0.0

# Build the entire workspace
cargo build

# Run the testing binary
cargo run -p conduit-testing 