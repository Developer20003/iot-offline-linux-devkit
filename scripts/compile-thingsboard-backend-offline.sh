#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/projects/iot-offline-build-sandbox"
SRC="$BASE/isolated-sources/thingsboard"
CACHE="$BASE/isolated-caches/maven"
IMAGE="maven:3.9.9-eclipse-temurin-17"

EXPECTED="c77335f4a524bb9fe0209806672c6ec7aea76141"

[[ -f "$SRC/pom.xml" && -d "$CACHE" ]] || {
    echo "ERROR: ThingsBoard source or Maven cache missing"
    exit 1
}

[[ "$(git -C "$SRC" rev-parse HEAD)" == "$EXPECTED" ]] || {
    echo "ERROR: ThingsBoard source commit mismatch"
    exit 1
}

docker run --rm \
  --network none \
  --pull never \
  --cpus=2 \
  --user "$(id -u):$(id -g)" \
  --workdir /src \
  --volume "$SRC:/src:z" \
  --volume "$CACHE:/offline-maven:z" \
  --env HOME=/tmp \
  --env MAVEN_OPTS="-Xmx1536m" \
  --entrypoint /bin/bash \
  "$IMAGE" -c '
    mvn -o -B -ntp \
      -Dmaven.repo.local=/offline-maven \
      -Dmaven.test.skip=true \
      -Dskip.yarn=true \
      -Dskip.ui.build=true \
      -Dpkg.skip=true \
      -Dlicense.skip=true \
      -pl application -am compile
  '

echo "THINGSBOARD_BACKEND_OFFLINE_BUILD=PASS"
