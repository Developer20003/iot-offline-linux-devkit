#!/usr/bin/env bash
set -euo pipefail

SANDBOX="$HOME/projects/iot-offline-build-sandbox/emqx-6.3.1"
IMAGE="ghcr.io/emqx/emqx-builder/6.1-8:1.19.1-28.4.1-4-ubuntu24.04"

if [ ! -f "$SANDBOX/mix.exs" ]; then
    echo "ERROR: EMQX sandbox not found"
    exit 1
fi

echo "=== EMQX OFFLINE COMPILATION ==="

docker run --rm --network none --pull never \
    --user "$(id -u):$(id -g)" \
    -v "$SANDBOX:/emqx:z" \
    -w /emqx \
    -e HOME=/tmp \
    -e PROFILE=emqx-enterprise \
    -e MIX_ENV=emqx-enterprise \
    -e MIX_HOME=/emqx/offline-mix \
    -e MIX_ARCHIVES=/emqx/offline-mix/archives \
    -e HEX_HOME=/emqx/offline-hex \
    -e HEX_OFFLINE=1 \
    -e ERL_LIBS=/emqx/_build/emqx-enterprise/lib \
    -e CARGO_NET_OFFLINE=true \
    -e ERL_FLAGS="+S 4:4" \
    --entrypoint /bin/bash \
    "$IMAGE" \
    -c './mix compile --no-deps-check --no-prune-code-paths'

echo "EMQX_OFFLINE_COMPILE=PASS"
