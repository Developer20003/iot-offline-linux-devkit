# Offline Build Verification Matrix

Verification date: 2026-11-12
Environment: openSUSE Leap 16.0, Docker, VMware.

## Verified compilation workflows

| Component | Verification | Result |
|---|---|---|
| EMQX Enterprise 6.3.1 | Isolated offline Erlang module recompilation | PASS |
| Kafka 4.2.2 | Gradle 9.2.1 offline JAR build, 169 tasks | PASS |
| Kafka-ThingsBoard Java bridge | Offline Java source compilation | PASS |
| Zigbee2MQTT 2.14.2 | Offline pnpm install and TypeScript build | PASS |
| ThingsBoard Angular UI | Offline production frontend bundle | PASS |
| ThingsBoard 4.3.1.6 backend | Maven offline reactor compilation, application -am | PASS |

## Evidence

- Kafka: `kafka-direct-offline-20261112-085644.log`
- Zigbee2MQTT: `zigbee-offline-retry-20261112-102059.log`
- ThingsBoard UI: `thingsboard-ui-offline-20261112-103411.log`
- ThingsBoard backend: `thingsboard-backend-offline-20261112-164619.log`

Logs remain local to the build sandbox and are not committed.

## Important limits

- Offline compilation used prepopulated dependency caches and source trees.
- EMQX validation was module recompilation, not a clean whole-project rebuild.
- ThingsBoard backend passed the `compile` phase, not a complete distribution package.
- Zigbee2MQTT installation skipped install scripts and bypassed registry
  supply-chain revalidation of the pinned lockfile.
- Java bridge production durability and multi-device handling are not yet verified.
- BLE gateway integration and Bluetooth hardware tests are pending.
- A fresh VM restore with all required offline assets remains unverified.
- Runtime images, database contents, access tokens and secrets are excluded
  from source control.

## Remaining release gates

1. BLE gateway development and hardware validation.
2. Offline asset inventory with SHA-256 checksums.
3. Clean-machine installation and dependency-cache reproduction.
4. Full integration, restart, persistence and rollback testing.
5. Licensing and secret-scanning review before distributing binaries.
