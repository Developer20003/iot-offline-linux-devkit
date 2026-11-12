#!/usr/bin/env bash
set -uo pipefail

BASE="$HOME/projects/iot-offline-build-sandbox"
SRC="$BASE/isolated-sources/thingsboard"
CACHE="$BASE/isolated-caches/maven"
IMAGE="maven:3.9.9-eclipse-temurin-17"

EXPECTED="c77335f4a524bb9fe0209806672c6ec7aea76141"

LOGDIR="$BASE/logs"
mkdir -p "$LOGDIR"

ONLINE_LOG="$LOGDIR/thingsboard-maven-cache-$(date +%Y%m%d-%H%M%S).log"
OFFLINE_LOG="$LOGDIR/thingsboard-backend-offline-$(date +%Y%m%d-%H%M%S).log"

echo "======================================"
echo " THINGSBOARD BACKEND BUILD"
echo "======================================"

echo
echo "=== 1. VERIFY SANDBOX ==="

if [[ ! -f "$SRC/pom.xml" ]]; then
    echo "ERROR: ThingsBoard source missing"
    exit 1
fi

if [[ ! -d "$CACHE" ]]; then
    echo "ERROR: Maven cache missing"
    exit 1
fi

ACTUAL="$(git -C "$SRC" rev-parse HEAD 2>/dev/null)"

if [[ "$ACTUAL" != "$EXPECTED" ]]; then
    echo "ERROR: Source commit mismatch"
    exit 1
fi

docker image inspect "$IMAGE" >/dev/null 2>&1 || {
    echo "ERROR: Maven Docker image missing"
    exit 1
}

echo "SOURCE: VERIFIED"
echo "CACHE: VERIFIED"

echo
echo "=== 2. PREPARE MAVEN DEPENDENCIES ==="
echo "Internet: ENABLED for this staging step only"
echo "Original ThingsBoard installation: UNCHANGED"

docker run --rm \
    --network bridge \
    --pull never \
    --cpus=2 \
    --user "$(id -u):$(id -g)" \
    --workdir /src \
    --volume "$SRC:/src:z" \
    --volume "$CACHE:/offline-maven:z" \
    --env HOME=/tmp \
    --env MAVEN_OPTS="-Xmx1536m" \
    --entrypoint /bin/bash \
    "$IMAGE" \
    -c '
      mvn -U -B -ntp \
        -Dmaven.repo.local=/offline-maven \
        -Dmaven.test.skip=true \
        -Dskip.yarn=true \
        -Dskip.ui.build=true \
        -Dpkg.skip=true \
        -Dlicense.skip=true \
        -pl application -am compile
    ' > "$ONLINE_LOG" 2>&1

ONLINE_RESULT=$?

echo
echo "=== MAVEN PREPARATION RESULT ==="
tail -n 35 "$ONLINE_LOG"

echo
echo "MAVEN_PREPARATION_EXIT_CODE=$ONLINE_RESULT"
echo "MAVEN_PREPARATION_LOG=$ONLINE_LOG"

if [[ "$ONLINE_RESULT" -ne 0 ]]; then
    echo
    echo "The dependency preparation or compilation failed."
    echo "Review this error before retrying offline."
    exit "$ONLINE_RESULT"
fi

echo
echo "=== 3. VERIFY COMPILATION WITHOUT INTERNET ==="
echo "Docker network: DISABLED"

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
    "$IMAGE" \
    -c '
      mvn -o -B -ntp \
        -Dmaven.repo.local=/offline-maven \
        -Dmaven.test.skip=true \
        -Dskip.yarn=true \
        -Dskip.ui.build=true \
        -Dpkg.skip=true \
        -Dlicense.skip=true \
        -pl application -am compile
    ' > "$OFFLINE_LOG" 2>&1

OFFLINE_RESULT=$?

echo
echo "=== OFFLINE BUILD RESULT ==="
tail -n 35 "$OFFLINE_LOG"

echo
echo "THINGSBOARD_BACKEND_OFFLINE_EXIT_CODE=$OFFLINE_RESULT"
echo "OFFLINE_BUILD_LOG=$OFFLINE_LOG"

echo
echo "=== RUNNING SERVICES ==="
docker ps --format 'table {{.Names}}\t{{.Status}}'

if [[ "$OFFLINE_RESULT" -eq 0 ]]; then
    echo
    echo "THINGSBOARD_BACKEND_OFFLINE_BUILD=PASS"
fi

echo
echo "THINGSBOARD BACKEND TEST COMPLETE"

exit "$OFFLINE_RESULT"
