# Original repo vs new Linux companion repo

## Existing original (do not overwrite)

`Developer20003/iot-offline-source-kit` release `v0.1.0-offline-preview`: 7 distribution ZIPs, source commit bundles, offline dependency caches, Docker image archives, runtime builds and 13 restoration scripts. Designed for WSL/Windows Docker and used to restore openSUSE.

## New companion (`iot-offline-linux-devkit`)

**Stage 1 / `v0.1.0-offline-linux-dev-preview`**

- Local source reference manifest and compiler/toolchain versions.
- Read-only Linux environment audit and no-network Java bridge compiler.
- Java bridge source (import from your openSUSE working kit) + bridge Compose template.
- Document tested Linux patches to upstream offline installer: SELinux labels; Bash command-array correction; Kafka restart; ThingsBoard install data; fresh-schema installation; PostgreSQL and Kafka data preservation.
- Manual command guide and exact test evidence.

**Stage 2 / `v0.2.0-offline-builds`**

- Fully tested, reproducible offline compilation of EMQX Enterprise, Kafka and ThingsBoard with exact toolchain/caches.
- Optional separate host-native Erlang/OTP fork (or validated fully local EMQX builder image) and offline RPM repo for openSUSE, plus dependency archives.
- Automated Linux installation/restore scripts and non-destructive migrations for existing deployments.
- Versioned runtime bridge image, build recipe, health checks, error handling, multi-device mappings.
- Zigbee2MQTT, BLE gateway, USB permissions and hardware test instructions.
- Offline smoke tests and checksums. WSL vs Linux tested matrix.

**Stage 3 / `v1.0.0-offline-linux-dev`**

- Clean-machine restore on an isolated VM, repeatable changed-source rebuild, running artifact deployment and rollback.
- Simulated VM restart and persistence verification.
- Release assets checksummed, documented, licensed and scrubbed of private state.

## Required offline release assets (NOT included in this starter ZIP)

1. EMQX builder Docker image archive (already loaded on user's VM; package by immutable digest and checksum).
2. Exact EMQX source dependencies, forked OTP 28.4.1-4 / Elixir 1.19.1-otp-28 / Rust 1.88.0 as supported by builder; Hex/Mix/Rebar3 caches verified.
3. Kafka 4.2.2 Gradle wrapper distribution, plugins, Scala 2.13 and Gradle cache, JDK 17 builder image.
4. ThingsBoard CE 4.3.1.6 Maven local repository plus JS frontend Node and Yarn/pnpm packages, Maven JDK 17 builder image, SQL and system data.
5. Node 22.22.2 / Python 3.12 images, Zigbee2MQTT resources and Python gateway wheelhouse.
6. Java bridge source, binary/image, offline build verification logs and deployment definition.
7. OpenSUSE host prerequisites (Docker engine/Compose/Git/Build tools) for a *fresh offline OS* when needed; a restored Docker image alone doesn't install Docker itself. Provide offline RPM repositories and key/signature verification for supported Leap revision.
8. License inventory and source notices.

## Secrets and private data NEVER publish

- `runtime/postgres/postgres.env`, `runtime/emqx/emqx.env`, device tokens.
- `/home/admin/.config/iot-offline/secrets/`, PG volumes or dumps with customer data.
- EMQX node cookies/cluster state, customer dashboards, private gateway keys.
- Container-generated runtime directories, logs, copied VM images.

## Critical release audit checklist

- [ ] Original archive untouched, commit manifest recorded.
- [ ] EMQX toolchain matches source `.tool-versions`.
- [ ] All Docker images available via `--pull never`.
- [ ] No build fetch attempted with `--network none`.
- [ ] EMQX modified-source clean rebuild PASS (not yet).
- [ ] Kafka modified-source clean rebuild PASS (not yet).
- [ ] ThingsBoard modified-source clean rebuild PASS (not yet).
- [ ] Java bridge offline compile PASS (on VM, source copied into new repo pending).
- [ ] SELinux-aware deployment PASS.
- [ ] EMQX->Kafka->ThingsBoard integration PASS (HTTP receipt); Latest Telemetry UI confirmation pending.
- [ ] Zigbee and BLE hardware verification (pending).
- [ ] Offline VM reboot/restore PASS (pending).
- [ ] All release asset hashes and legal notices included.
- [ ] No secrets inside `git status`, `git archive`, archives or generated logs.
