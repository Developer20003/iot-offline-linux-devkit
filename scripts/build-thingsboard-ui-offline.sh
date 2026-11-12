#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/projects/iot-offline-build-sandbox"
UI="$BASE/isolated-sources/thingsboard/ui-ngx"
IMAGE="node:22.22.2-bookworm"

if [[ ! -f "$UI/package.json" ||
      ! -d "$UI/node_modules" ]]; then
    echo "ERROR: ThingsBoard UI sandbox is incomplete"
    exit 1
fi

echo "=== THINGSBOARD UI OFFLINE BUILD ==="

docker run --rm \
  --network none \
  --pull never \
  --memory=5g \
  --cpus=4 \
  --user "$(id -u):$(id -g)" \
  --workdir /src \
  --volume "$UI:/src:z" \
  --env HOME=/tmp \
  --env COREPACK_ENABLE_NETWORK=0 \
  --entrypoint /bin/bash \
  "$IMAGE" \
  -c 'npm run build:prod'

echo "THINGSBOARD_UI_OFFLINE_BUILD=PASS"
