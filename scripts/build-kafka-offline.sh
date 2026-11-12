#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/projects/iot-offline-build-sandbox"
SRC="$BASE/isolated-sources/kafka"
CACHE="$BASE/isolated-caches/gradle"
IMAGE="eclipse-temurin:17-jdk"

[[ -f "$SRC/build.gradle" ]] || {
    echo "ERROR: Kafka sandbox source missing"
    exit 1
}

[[ -d "$CACHE" ]] || {
    echo "ERROR: Offline Gradle cache missing"
    exit 1
}

GRADLE="$(find "$CACHE" -type f \
    -path '*/gradle-9.2.1/bin/gradle' \
    -print -quit)"

[[ -n "$GRADLE" ]] || {
    echo "ERROR: Gradle 9.2.1 not found"
    exit 1
}

docker run --rm --network none --pull never \
    --user "$(id -u):$(id -g)" \
    --workdir /src \
    --volume "$SRC:/src:z" \
    --volume "$CACHE:/offline-gradle:z" \
    --env HOME=/tmp \
    --env GRADLE_USER_HOME=/offline-gradle \
    --env "GRADLE_BIN=/offline-gradle${GRADLE#"$CACHE"}" \
    --entrypoint /bin/bash \
    "$IMAGE" \
    -c 'exec "$GRADLE_BIN" --offline --no-daemon --max-workers=2 -Dorg.gradle.parallel=false jar'

echo "KAFKA_OFFLINE_BUILD=PASS"
