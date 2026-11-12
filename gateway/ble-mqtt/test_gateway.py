import json
import subprocess
import sys
import unittest

from gateway import payload_for


class GatewayTest(unittest.TestCase):

    def test_payload(self):
        event = payload_for(
            bytes.fromhex("0102ff"),
            "Offline_Telemetry_Test",
            "simulated",
        )

        self.assertEqual(
            event["device_name"],
            "Offline_Telemetry_Test",
        )
        self.assertEqual(
            event["ble_value_hex"],
            "0102ff",
        )
        self.assertGreater(event["timestamp_ms"], 0)

    def test_simulation(self):
        result = subprocess.run(
            [sys.executable, "gateway.py", "--simulate"],
            capture_output=True,
            text=True,
            check=True,
        )

        envelope = json.loads(result.stdout)

        self.assertEqual(
            envelope["topic"],
            "iot/telemetry/Offline_Telemetry_Test",
        )
        self.assertEqual(
            envelope["payload"]["device_name"],
            "Offline_Telemetry_Test",
        )


if __name__ == "__main__":
    unittest.main()
