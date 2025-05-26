FROM rustlang/rust:nightly-slim as builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Cargo.toml Cargo.lock ./
COPY conduit-core/ ./conduit-core/
COPY conduit-daemon/ ./conduit-daemon/
COPY conduit-cli/ ./conduit-cli/
COPY conduit-testing/ ./conduit-testing/

RUN cargo build --release --bin conduit-daemon

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -u 1000 conduit \
    && mkdir -p /data/conduit /data/ldk \
    && chown -R conduit:conduit /data

COPY --from=builder /app/target/release/conduit-daemon /usr/local/bin/conduit-daemon

USER conduit

EXPOSE 8080 9735

ENTRYPOINT ["conduit-daemon"]