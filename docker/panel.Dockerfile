# syntax=docker/dockerfile:1
# Lunar Base panel image for docker-compose scheme D.
#
# Runs as root by design (the project choice): runtime venv/pip/apt/build work
# out of the box; compose persists /app/panel/.venv and /app/panel/tools in
# named volumes so those changes survive container recreation.
#
# Build context is the repository root (needs panel/ and server/ for the shim).

# ---- stage 1: build the Go grant shim against the server sources -----------
FROM golang:1.25-bookworm AS shim
ARG GOPROXY=https://proxy.golang.org,direct
ENV GOPROXY=${GOPROXY}
WORKDIR /src
COPY server/go.mod server/go.sum /src/server/
RUN --mount=type=cache,target=/go/pkg/mod cd /src/server && go mod download
COPY server/ /src/server/
COPY panel/tools/grant/src/ /src/panel/tools/grant/src/
RUN --mount=type=cache,target=/go/pkg/mod mkdir -p /src/server/cmd/lunar-base-grant \
 && cp /src/panel/tools/grant/src/*.go /src/server/cmd/lunar-base-grant/ \
 && cd /src/server && go build -o /out/grant ./cmd/lunar-base-grant/

# ---- stage 2: runtime -------------------------------------------------------
FROM python:3.12-slim-bookworm
ARG APKTOOL_VERSION=2.11.1
ARG APT_MIRROR=
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONUTF8=1 \
    TZ=UTC

# JDK (keytool) + Android build-tools (zipalign/apksigner) live in the image,
# so the host never needs them.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "$APT_MIRROR" ]; then \
        sed -i "s|deb.debian.org|${APT_MIRROR}|g" /etc/apt/sources.list.d/debian.sources 2>/dev/null \
        || sed -i "s|deb.debian.org|${APT_MIRROR}|g" /etc/apt/sources.list; \
    fi \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      openjdk-17-jdk-headless android-sdk-build-tools curl ca-certificates unzip \
 && rm -rf /var/lib/apt/lists/*

# Vendored apktool (jar verified as a zip before use): resolve the latest
# release asset from the GitHub API, then fall back to the pinned version.
RUN mkdir -p /app/panel/tools/apktool \
 && URL="$(curl -fsSL "https://api.github.com/repos/iBotPeaches/Apktool/releases/latest" | grep -o 'https://[^"]*\.jar' | head -1)" \
 && [ -n "$URL" ] || URL="https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar" \
 && echo "downloading $URL" \
 && curl -fL --retry 3 "$URL" -o /app/panel/tools/apktool/apktool.jar \
 && test "$(head -c 2 /app/panel/tools/apktool/apktool.jar)" = "PK"

WORKDIR /app
COPY panel/ /app/panel/
# Mount points for server/db and server/assets (kept as a real directory even
# when nothing is mounted, so config path resolution never fails).
RUN --mount=type=cache,target=/root/.cache/pip mkdir -p /app/server \
 && python -m venv /app/panel/.venv \
 && /app/panel/.venv/bin/pip install --no-cache-dir --upgrade pip \
 && /app/panel/.venv/bin/pip install -r /app/panel/web/requirements.txt

COPY --from=shim /out/grant /app/panel/tools/grant/grant
RUN chmod +x /app/panel/tools/grant/grant

# Docker mode: control the stack through the restricted proxy, probe the
# server service, and read server logs from the Docker API.
ENV LUNAR_CONTROL_MODE=docker \
    LUNAR_SERVER_HOST=server \
    LUNAR_LOG_SOURCE=docker \
    DOCKER_HOST=tcp://dockerproxy:2375

WORKDIR /app/panel
EXPOSE 8888
# No USER directive: root by design (see docs/DOCKER.md).
CMD ["/app/panel/.venv/bin/python", "-m", "web"]
