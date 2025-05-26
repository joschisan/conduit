# Simple Dockerfile for conduit daemon (testing)
FROM rustlang/rust:nightly-slim as builder

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy workspace files
COPY Cargo.toml Cargo.lock ./
COPY conduit-core/ ./conduit-core/
COPY conduit-daemon/ ./conduit-daemon/
COPY conduit-cli/ ./conduit-cli/
COPY conduit-testing/ ./conduit-testing/

# Build the daemon
RUN cargo build --release --bin conduit-daemon

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary
COPY --from=builder /app/target/release/conduit-daemon /usr/local/bin/conduit-daemon

# Create app user
RUN useradd -m -u 1000 conduit

# Set working directory first
WORKDIR /home/conduit

# Switch to user and create data directories
USER conduit

RUN mkdir -p data/conduit data/ldk

# Expose ports
EXPOSE 8080 9735

# Run the daemon
ENTRYPOINT ["conduit-daemon"] 