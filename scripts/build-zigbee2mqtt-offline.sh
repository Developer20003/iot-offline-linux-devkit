#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/projects/iot-offline-build-sandbox"
SRC="$BASE/isolated-sources/zigbee2mqtt"
CACHE="$BASE/isolated-caches/pnpm"
PNPM="/pnpm/corepack/v1/pnpm/11.26.0/bin/pnpm.cjs"
EXPECTED="344b6e03b43644c97154a72ca9eae17193c553a2"

[[ -f "$SRC/pnpm-lock.yaml" ]] || {
    echo "ERROR: Zigbee2MQTT sandbox missing"
    exit 1
}

[[ -f "$CACHE/corepack/v1/pnpm/11.26.0/bin/pnpm.cjs" ]] || {
    echo "ERROR: Offline pnpm missing"
    exit 1
}

[[ "$(git -C "$SRC" rev-parse HEAD)" == "$EXPECTED" ]] || {
    echo "ERROR: Source commit mismatch"
    exit 1
}

docker run --rm --network none --pull never \
    --user "$(id -u):$(id -g)" \
    --workdir /src \
    --volume "$SRC:/src:z" \
    --volume "$CACHE:/pnpm:z" \
    --env HOME=/tmp \
    --env CI=true \
    --env COREPACK_ENABLE_NETWORK=0 \
    --entrypoint /bin/sh \
    node:22.22.2-bookworm -ec "
        node '$PNPM' install \
          --offline \
          --frozen-lockfile \
          --ignore-scripts \
          --config.trust-lockfile=true \
          --store-dir=/pnpm/store

        node '$PNPM' run build
    "

echo "ZIGBEE_OFFLINE_BUILD=PASS"
echo "NOTE: Native install scripts and hardware tests excluded"
