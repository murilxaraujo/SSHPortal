# syntax=docker/dockerfile:1.6
FROM swift:6.2-noble AS builder
WORKDIR /app
COPY Package.swift Package.resolved ./
RUN swift package resolve
COPY Sources/ Sources/
COPY Tests/ Tests/
RUN swift build --product App -c release --static-swift-stdlib && \
    cp "$(swift build --product App -c release --show-bin-path)/App" /app/App

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libxml2 \
    && rm -rf /var/lib/apt/lists/*
RUN userdel -r ubuntu 2>/dev/null || true && \
    groupadd -g 1000 sshportal && \
    useradd -u 1000 -g sshportal -s /bin/false -m sshportal
WORKDIR /app
COPY --from=builder /app/App /app/App
USER sshportal
EXPOSE 8080
ENV HOST=0.0.0.0 PORT=8080 KEYS_FILE=/config/keys.yaml
ENTRYPOINT ["/app/App"]
