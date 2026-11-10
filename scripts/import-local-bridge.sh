#!/usr/bin/env bash
set -euo pipefail
ROOT="${OFFLINE_KIT_ROOT:-$HOME/projects/iot-offline-development}"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/gateway/offline-kafka-thingsboard/src/OfflineKafkaThingsBoardBridge.java"
TARGET="$DEST/gateway/offline-kafka-thingsboard/src/OfflineKafkaThingsBoardBridge.java"
[[ -f "$SRC" && ! -L "$SRC" ]] || { echo "MISSING/UNSAFE SOURCE: $SRC"; exit 1; }
[[ ! -e "$TARGET" ]] || { echo "REFUSING TO OVERWRITE: $TARGET"; exit 1; }
mkdir -p "$(dirname "$TARGET")"
install -m 0644 "$SRC" "$TARGET"
echo "BRIDGE SOURCE IMPORTED: $TARGET"
echo 'Review and commit only the .java file. NEVER commit the private token.'
