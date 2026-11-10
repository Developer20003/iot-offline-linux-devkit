# Offline Linux command guide

## 0. Never modify the baseline repo in place

```bash
export OFFLINE_KIT_ROOT="$HOME/projects/iot-offline-development"
export OFFLINE_DEVKIT_ROOT="$HOME/projects/iot-offline-linux-devkit-starter"
cd "$OFFLINE_KIT_ROOT"
docker compose ps -a
```

Check that all four core services and bridge are healthy before further work.

## 1. Audit tools with Internet disabled

```bash
cd "$OFFLINE_DEVKIT_ROOT"
bash scripts/audit-offline-dev.sh
```

Inspect exact EMQX fork toolchain in its offline builder image (note: system Erlang is **not** a supported substitute):

```bash
docker run --rm --network none --pull never \
  --entrypoint /bin/bash \
  ghcr.io/emqx/emqx-builder/6.1-8:1.19.1-28.4.1-4-ubuntu24.04 \
  -lc 'erl -noshell -eval '\''io:format("OTP=~s~n",[erlang:system_info(otp_release)]),halt().'\''; elixir --version; command -v rebar3 || true; rustc --version; make --version | head -1'
```

## 2. Edit your bridge and compile offline

```bash
cd "$OFFLINE_DEVKIT_ROOT"
bash scripts/import-local-bridge.sh
# Edit gateway/offline-kafka-thingsboard/src/OfflineKafkaThingsBoardBridge.java
bash scripts/build-offline-bridge.sh
```

The preexisting bridge has only been validated for one named device, at-least-once delivery. Do not call it production-ready. Before production: add explicit device/token mapping, dead-letter/error handling, retry with backoff, delivery deduplication or timestamp/idempotency strategy, observability and protected configuration.

## 3. Edit / compile EMQX (offline test, not guaranteed until verified)

EMQX source is pinned. In this exact revision, its build process uses its own `make`/`mix`/`rebar3` orchestration. The builder has the EMQX-forked Erlang/OTP, Elixir and Rust toolchain.

```bash
export OFFLINE_KIT_ROOT="$HOME/projects/iot-offline-development"
# IMPORTANT: this builds in the restored EMQX source tree; back up any local modifications first.
docker run --rm --network none --pull never \
  --user "$(id -u):$(id -g)" \
  --workdir /emqx \
  --volume "$OFFLINE_KIT_ROOT/sources/emqx:/emqx:z" \
  --entrypoint /bin/bash \
  ghcr.io/emqx/emqx-builder/6.1-8:1.19.1-28.4.1-4-ubuntu24.04 \
  -lc 'make emqx-enterprise-compile'
```

If this fails attempting to fetch dependencies, **do not enable Internet**. Inspect which Hex/Mix/Rebar3/dependency or compiler cache is absent, add that to future release assets on an Internet-enabled packaging machine, then retest offline. The existing `_build` artifact proves runtime availability, **not** that the full source rebuild is reproducible offline.

## 4. Edit / compile Kafka (offline test)

Kafka 4.2.2 source supports JDK 17 and Scala 2.13. The wrapper and all plugins must exist in the local caches.

```bash
export OFFLINE_KIT_ROOT="$HOME/projects/iot-offline-development"
# Run in a controlled source working copy; Gradle generates build outputs.
docker run --rm --network none --pull never \
  --user "$(id -u):$(id -g)" \
  --workdir /kafka \
  --volume "$OFFLINE_KIT_ROOT/sources/kafka:/kafka:z" \
  --volume "$OFFLINE_KIT_ROOT/caches/gradle:/offline-gradle:z" \
  --env GRADLE_USER_HOME=/offline-gradle \
  --entrypoint /bin/bash eclipse-temurin:17-jdk \
  -lc './gradlew --offline --no-daemon jar'
```

If Gradle distribution or plugin dependencies are missing, report the missing artifact and extend the packaged cache; do not download on the offline server.

## 5. Edit / compile ThingsBoard (offline test)

Requires Java 17, Maven and packaged frontend dependencies. To test Java build only (not full UI packaging):

```bash
export OFFLINE_KIT_ROOT="$HOME/projects/iot-offline-development"
docker run --rm --network none --pull never \
  --user "$(id -u):$(id -g)" \
  --workdir /thingsboard \
  --volume "$OFFLINE_KIT_ROOT/sources/thingsboard:/thingsboard:z" \
  --volume "$OFFLINE_KIT_ROOT/caches/maven:/offline-maven:z" \
  --entrypoint /bin/bash maven:3.9.9-eclipse-temurin-17 \
  -lc 'mvn -o -Dmaven.repo.local=/offline-maven -DskipTests -Dlicense.skip=true package'
```

This command is a **test candidate**; the project may require frontend plugins or other build phases and may fail until the caches are complete. Do not assume `-Dlicense.skip` is a supported project property. Capture the missing-dependency evidence and adjust build profiles for exact source revision.

## 6. Linux-specific runtime corrections to publish

From the verified openSUSE deployment:

- Add `:z` / `:ro,z` to bind mounts that need SELinux relabeling.
- Change Bash entrypoint service command into a single array element for both EMQX and Kafka: `command: ["exec /opt/... ..."]`.
- Set Kafka `restart: unless-stopped`.
- Start ThingsBoard with `-Dinstall.data_dir=/install-data` while mounting the installation resources.
- Provide a **fresh** PostgreSQL + ThingsBoard schema installer path in addition to backup restoration; never rerun the initial installer on a populated database.
- Initialize Kafka KRaft only once; preserve `meta.properties` and data across restarts.
- Keep private environment files out of repositories and releases.

## 7. Bridge Compose migration (later; avoid duplicate consumers)

The template `compose/bridge.compose.yaml` is a proposal for persistent restart behavior and easier redeployment. Before using it: validate `docker compose config`, ensure source is imported and compiled, and stop/remove only the **existing manually-created bridge container** after a backup. Never run two bridge instances using the same client ID/group without explicitly designing consumer-group behavior.

```bash
export OFFLINE_DEVKIT_ROOT="$HOME/projects/iot-offline-linux-devkit-starter"
export OFFLINE_KIT_ROOT="$HOME/projects/iot-offline-development"
export OFFLINE_TB_TOKEN_PATH="$HOME/.config/iot-offline/secrets/thingsboard-test-device-token"
# Read-only config verification:
docker compose -f "$OFFLINE_DEVKIT_ROOT/compose/bridge.compose.yaml" config --quiet
# Start only after explicitly migrating the existing standalone bridge:
# docker compose -f "$OFFLINE_DEVKIT_ROOT/compose/bridge.compose.yaml" -p iot-offline-bridge up -d --no-build --pull never
```

## 8. Tags/releases

```bash
# Run only after creating your GitHub repo, committing your own files and verifying no secrets.
# git remote add origin git@github.com:Developer20003/iot-offline-linux-devkit.git
# git push -u origin main
# git tag -a v0.1.0-offline-linux-dev-preview -m 'Linux offline development preview'
# git push origin v0.1.0-offline-linux-dev-preview
```

GitHub Release assets are separate: put large compiled tools/caches into appropriately licensed ZIP/TAR archives with a SHA256SUMS manifest. Create your release from the new tag; do **not** claim all builds are offline until tested in a disconnected VM.
