# IoT Offline Linux Development Kit (companion repository)

**Status: starter repository / not yet a verified fully offline rebuild release.**

This repository complements, rather than replaces, the existing `iot-offline-source-kit` Windows Docker / WSL distribution and its Linux-restored installation.

- Original release: `Developer20003/iot-offline-source-kit`, tag `v0.1.0-offline-preview`
- Existing openSUSE development root: `/home/admin/projects/iot-offline-development`
- Proposed GitHub repo name: `iot-offline-linux-devkit`
- First proposed tag (only after validation): `v0.1.0-offline-linux-dev-preview`

## Verified on openSUSE (2026-11-09)

- PostgreSQL 17 healthy; ThingsBoard CE 4.3.1.6 HTTP operational and database initialized.
- EMQX Enterprise 6.3.1 dashboard and MQTT publish/subscribe functional.
- Kafka 4.2.2 producer/consumer functional.
- EMQX rule `offline_mqtt_to_kafka`, connector `offline_kafka_connector`, sink `offline_telemetry_sink`, Kafka topic `iot-telemetry` proven end-to-end.
- Editable Java 17 bridge built offline and forwarding telemetry from Kafka to ThingsBoard with manual offset commit.
- ThingsBoard HTTP telemetry forwarding ACK confirmed; check Latest Telemetry in UI for persistent visibility.
- **Not yet proven:** clean rebuilds of all four third-party projects with network disabled, Zigbee/BLE hardware tests, multi-device durable bridge, clean-machine restore of the new devkit, resilience after VM reboot.

## Architecture

MQTT Device -> EMQX -> Kafka (`iot-telemetry`) -> Java offline bridge -> ThingsBoard -> PostgreSQL.

## What belongs in this repo

1. Development scripts, pinned manifests, tested patches and sanitized configuration templates.
2. **Your own** editable Kafka-to-ThingsBoard bridge source, integration tests and runtime Docker Compose definition.
3. Offline build instructions for EMQX, Kafka, ThingsBoard, Zigbee2MQTT, BLE gateway.
4. Release manifests, third-party licensing notices, reproducible offline checks, no-internet test reports.
5. GitHub Release *assets* for large, verified, redistributable toolchains and dependency caches, **not** Git blobs.

## What stays in existing repo

The 7-part baseline offline source/runtime distribution (`01`–`07` ZIPs), baseline restoration scripts and Windows/WSL Docker instructions. Do not re-upload gigabytes in Git or overwrite the original release. This repository records the reference baseline and releases only additive, version-matched development assets.

## Fast start on openSUSE

```bash
# Extract this starter into your projects directory (or clone your new GitHub repo).
cd ~/projects/iot-offline-linux-devkit
bash scripts/audit-offline-dev.sh
bash scripts/import-local-bridge.sh
bash scripts/build-offline-bridge.sh
```

Scripts default to `/home/admin/projects/iot-offline-development` but honor `OFFLINE_KIT_ROOT`.

> `import-local-bridge.sh` copies only the authored `.java` source from the working Linux kit, never an access token, password, Docker volume or runtime database. `build-offline-bridge.sh` compiles with `--network none --pull never`.

Read `docs/COMMAND-GUIDE.md` and `docs/RELEASE-PLAN.md` before modifying the running platform. The `compose/bridge.compose.yaml` file is a proposed replacement for the separately running Java bridge; do **not** start it while that container exists.

## Safety

- Never commit `*.env` with secrets, device access tokens, EMQX cookies, database files, VM state, service logs or runtime volumes.
- Keep `/home/admin/.config/iot-offline/secrets/` outside Git.
- EMQX is source-available under BSL 1.1; confirm redistribution and commercial/embedded use rights before publishing binaries or deploying for customers.
- Rebuilds must produce new staged outputs and be tested before replacing running JARs/EMQX releases/Kafka binaries.
- No script in this starter modifies the running database or restarts any existing service.
