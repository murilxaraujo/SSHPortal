# syntax=docker/dockerfile:1.6
FROM swift:6.0-jammy AS builder
WORKDIR /app
COPY Package.swift Package.resolved ./
RUN swift package resolve
COPY Sources/ Sources/
RUN swift build -c release --static-swift-stdlib && \
    cp "$(swift build -c release --show-bin-path)/App" /app/App

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libxml2 \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd -g 1000 sshportal && useradd -u 1000 -g sshportal -s /bin/false -m sshportal
WORKDIR /app
COPY --from=builder /app/App /app/App
USER sshportal
EXPOSE 8080
ENV HOST=0.0.0.0 PORT=8080 KEYS_FILE=/config/keys.yaml
ENTRYPOINT ["/app/App"]
