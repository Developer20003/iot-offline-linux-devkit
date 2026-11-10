#!/usr/bin/env bash
set -euo pipefail
ROOT="${OFFLINE_KIT_ROOT:-$HOME/projects/iot-offline-development}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$REPO/gateway/offline-kafka-thingsboard"
DIST="$ROOT/runtime/kafka/distribution"
[[ -s "$BASE/src/OfflineKafkaThingsBoardBridge.java" ]] || { echo 'ERROR: import Java source first'; exit 1; }
[[ -d "$DIST/libs" ]] || { echo 'ERROR: local Kafka libs missing'; exit 1; }
docker image inspect eclipse-temurin:17-jdk >/dev/null
mkdir -p "$BASE/build"
docker run --rm --network none --pull never \
  --user "$(id -u):$(id -g)" \
  --workdir /workspace --entrypoint /bin/bash \
  --volume "$BASE:/workspace:z" \
  --volume "$DIST:/opt/kafka:ro,z" \
  eclipse-temurin:17-jdk \
  -ec 'javac -encoding UTF-8 -cp "/opt/kafka/libs/*" -d build src/OfflineKafkaThingsBoardBridge.java; test -s build/OfflineKafkaThingsBoardBridge.class'
echo 'OFFLINE JAVA BRIDGE BUILD: PASS'
echo "Class: $BASE/build/OfflineKafkaThingsBoardBridge.class"
