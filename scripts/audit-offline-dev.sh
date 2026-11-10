#!/usr/bin/env bash
set -euo pipefail
ROOT="${OFFLINE_KIT_ROOT:-$HOME/projects/iot-offline-development}"
IMAGE='ghcr.io/emqx/emqx-builder/6.1-8:1.19.1-28.4.1-4-ubuntu24.04'
echo '=== LINUX OFFLINE DEV AUDIT (READ ONLY) ==='
for project in emqx kafka thingsboard zigbee2mqtt; do
  if [[ -d "$ROOT/sources/$project/.git" ]]; then
    echo "$project commit: $(git -C "$ROOT/sources/$project" rev-parse HEAD)"
  else
    echo "MISSING SOURCE: $project"
  fi
done
for img in "$IMAGE" 'eclipse-temurin:17-jdk' 'maven:3.9.9-eclipse-temurin-17' 'node:22.22.2-bookworm' 'python:3.12' 'postgres:17'; do
  if docker image inspect "$img" >/dev/null 2>&1; then echo "IMAGE FOUND: $img"; else echo "IMAGE MISSING: $img"; fi
done
for path in caches/emqx caches/maven caches/gradle caches/yarn caches/pnpm caches/pip sources/emqx/deps sources/emqx/_build sources/kafka/.gradle sources/thingsboard/ui-ngx/node_modules runtime/thingsboard/install-data; do
  [[ -d "$ROOT/$path" ]] && echo "FOUND: $path" || echo "MISSING: $path"
done
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  docker run --rm --network none --pull never --entrypoint /bin/bash "$IMAGE" -lc '
    for t in erl erlc elixir mix make gcc rustc rebar3; do
      if command -v "$t" >/dev/null 2>&1; then echo "TOOL FOUND: $t"; else echo "TOOL NOT IN PATH: $t"; fi
    done
    erl -noshell -eval '\''io:format("EMQX BUILDER OTP: ~s~n",[erlang:system_info(otp_release)]),halt().'\''
    elixir --version | head -4
    rustc --version
  '
fi
for name in iot-postgres iot-emqx iot-kafka iot-thingsboard iot-offline-kafka-tb-bridge; do
  if docker container inspect "$name" >/dev/null 2>&1; then
    echo "$name: $(docker inspect --format '{{.State.Status}}' "$name")"
  else echo "$name: NOT PRESENT"; fi
done
printf '\n'
df -h "$ROOT"
echo 'AUDIT COMPLETE: NO SOURCES OR CONTAINERS MODIFIED'
