# syntax=docker/dockerfile:1.7

ARG TARGET_TRIPLE=aarch64-unknown-linux-musl

FROM --platform=$TARGETPLATFORM rust:1.88.0-alpine3.20 AS builder
ARG TARGET_TRIPLE

RUN apk add --no-cache build-base musl-dev perl pkgconfig
RUN rustup target add "${TARGET_TRIPLE}"

WORKDIR /build

COPY src-tauri/proxyd/Cargo.toml src-tauri/proxyd/Cargo.lock /build/src-tauri/proxyd/
COPY src-tauri/proxyd/src/main.rs /build/src-tauri/proxyd/src/main.rs
COPY src-tauri/src/auth.rs /build/src-tauri/src/auth.rs
COPY src-tauri/src/models.rs /build/src-tauri/src/models.rs
COPY src-tauri/src/proxy_daemon.rs /build/src-tauri/src/proxy_daemon.rs
COPY src-tauri/src/proxy_service.rs /build/src-tauri/src/proxy_service.rs
COPY src-tauri/src/state.rs /build/src-tauri/src/state.rs
COPY src-tauri/src/store.rs /build/src-tauri/src/store.rs
COPY src-tauri/src/usage.rs /build/src-tauri/src/usage.rs
COPY src-tauri/src/utils.rs /build/src-tauri/src/utils.rs

RUN cargo build --release --target "${TARGET_TRIPLE}" --manifest-path src-tauri/proxyd/Cargo.toml

FROM alpine:3.20 AS runtime
ARG TARGET_TRIPLE

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app
ENV CODEX_TOOLS_PROXY_DATA_DIR=/data

COPY packaging/dockroot-proxyd/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --from=builder /build/src-tauri/proxyd/target/${TARGET_TRIPLE}/release/codex-tools-proxyd /usr/local/bin/codex-tools-proxyd

RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/codex-tools-proxyd

EXPOSE 8787
VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
