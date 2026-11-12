#!/usr/bin/env python3
"""BLE GATT notification to MQTT telemetry gateway."""

import argparse
import asyncio
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys
import time


def payload_for(data: bytes, device: str, characteristic: str) -> dict:
    return {
        "device_name": device,
        "source": "ble",
        "ble_characteristic": characteristic,
        "ble_value_hex": data.hex(),
        "timestamp_ms": int(
            datetime.now(timezone.utc).timestamp() * 1000
        ),
    }


def publish(mqtt_client, topic: str, event: dict) -> None:
    body = json.dumps(event, separators=(",", ":"))
    info = mqtt_client.publish(topic, body, qos=1)
    info.wait_for_publish(timeout=10)

    if not info.is_published():
        raise TimeoutError("MQTT publish was not acknowledged")


async def run_live(device, topic, address, characteristic):
    try:
        from bleak import BleakClient
        import paho.mqtt.client as mqtt
    except ImportError as exc:
        raise SystemExit(
            f"LIVE_MODE_REQUIRES_BLEAK_AND_PAHO: {exc}"
        ) from exc

    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id="offline-ble-gateway",
    )

    username = os.getenv("MQTT_USERNAME")
    password_file = os.getenv("MQTT_PASSWORD_FILE")

    if bool(username) != bool(password_file):
        raise SystemExit(
            "Set both MQTT_USERNAME and MQTT_PASSWORD_FILE, "
            "or neither"
        )

    if username:
        password = Path(password_file).read_text(
            encoding="utf-8"
        ).strip()
        client.username_pw_set(username, password)

    ca = os.getenv("MQTT_TLS_CA")
    if ca:
        client.tls_set(ca_certs=ca)

    client.connect(
        os.getenv("MQTT_HOST", "127.0.0.1"),
        int(os.getenv("MQTT_PORT", "1883")),
        60,
    )
    client.loop_start()

    try:
        deadline = time.monotonic() + 15

        while not client.is_connected():
            if time.monotonic() >= deadline:
                raise TimeoutError("MQTT connection timeout")
            await asyncio.sleep(0.2)

        print("MQTT_CONNECTED", flush=True)

        while True:
            queue = asyncio.Queue(maxsize=200)

            try:
                async with BleakClient(
                    address, timeout=20
                ) as ble:

                    def on_notify(sender, data):
                        try:
                            queue.put_nowait(bytes(data))
                        except asyncio.QueueFull:
                            print(
                                "WARNING: BLE queue full",
                                file=sys.stderr,
                                flush=True,
                            )

                    await ble.start_notify(
                        characteristic, on_notify
                    )
                    print("BLE_CONNECTED", flush=True)

                    while ble.is_connected:
                        try:
                            data = await asyncio.wait_for(
                                queue.get(), timeout=2
                            )
                        except asyncio.TimeoutError:
                            continue

                        event = payload_for(
                            data, device, characteristic
                        )

                        await asyncio.to_thread(
                            publish, client, topic, event
                        )
                        print("MQTT_PUBLISHED", flush=True)

            except Exception as exc:
                print(
                    f"BLE_GATEWAY_ERROR: {exc}",
                    file=sys.stderr,
                    flush=True,
                )

            await asyncio.sleep(5)

    finally:
        client.disconnect()
        client.loop_stop()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--simulate", action="store_true")
    parser.add_argument("--hex", default="0102ff")
    args = parser.parse_args()

    device = os.getenv(
        "BLE_DEVICE_NAME", "Offline_Telemetry_Test"
    )
    topic = os.getenv(
        "BLE_MQTT_TOPIC",
        f"iot/telemetry/{device}",
    )
    characteristic = os.getenv("BLE_NOTIFY_UUID", "")

    if args.simulate:
        print(json.dumps({
            "topic": topic,
            "payload": payload_for(
                bytes.fromhex(args.hex),
                device,
                characteristic or "simulated",
            ),
        }, sort_keys=True))
        return

    address = os.getenv("BLE_DEVICE_ADDRESS", "")

    if not address or not characteristic:
        parser.error(
            "Live mode requires BLE_DEVICE_ADDRESS "
            "and BLE_NOTIFY_UUID"
        )

    asyncio.run(
        run_live(device, topic, address, characteristic)
    )


if __name__ == "__main__":
    main()
