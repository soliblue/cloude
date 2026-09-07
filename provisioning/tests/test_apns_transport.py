import base64
import json
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import httpx
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature

from app.services import apns


class APNSTransportTests(unittest.IsolatedAsyncioTestCase):
    async def test_signed_http2_delivery_and_environment_routing(self):
        key = ec.generate_private_key(ec.SECP256R1())
        config = SimpleNamespace(
            apns_key_id="fixture-key",
            apns_team_id="fixture-team",
            apns_auth_key_content=key.private_bytes(
                serialization.Encoding.PEM,
                serialization.PrivateFormat.PKCS8,
                serialization.NoEncryption(),
            ).decode(),
            apns_topic="soli.Cloude",
            apns_use_sandbox=False,
        )
        original_client = httpx.AsyncClient
        hosts = []
        routing = {}

        def handler(request):
            hosts.append(request.url.host)
            self.assertEqual(request.method, "POST")
            self.assertEqual(request.url.path, "/3/device/" + "a" * 64)
            self.assertEqual(request.headers["apns-topic"], "soli.Cloude")
            self.assertEqual(request.headers["apns-push-type"], "alert")
            header, claims, signature = request.headers["authorization"].removeprefix("bearer ").split(".")
            self.assertEqual(json.loads(base64.urlsafe_b64decode(header + "==")), {"alg": "ES256", "kid": "fixture-key"})
            payload = json.loads(base64.urlsafe_b64decode(claims + "=="))
            self.assertEqual(payload["iss"], "fixture-team")
            self.assertLess(abs(payload["iat"] - time.time()), 5)
            raw = base64.urlsafe_b64decode(signature + "==")
            self.assertEqual(len(raw), 64)
            key.public_key().verify(
                encode_dss_signature(int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:], "big")),
                f"{header}.{claims}".encode(),
                ec.ECDSA(hashes.SHA256()),
            )
            self.assertEqual(json.loads(request.content), {
                "aps": {"alert": {"title": "Ready", "body": "Task complete"}, "sound": "default"},
                "sessionId": "session",
                **routing,
            })
            return httpx.Response(200)

        def client(**arguments):
            self.assertTrue(arguments["http2"])
            return original_client(**arguments, transport=httpx.MockTransport(handler))

        with patch.object(apns, "settings", return_value=config), patch.object(apns.httpx, "AsyncClient", side_effect=client):
            for environment in ["production", "sandbox"]:
                self.assertEqual(await apns.send({"token": "a" * 64, "environment": environment}, "Ready", "Task complete", "session"), (200, {}))
            config.apns_use_sandbox = True
            self.assertEqual(await apns.send({"token": "a" * 64, "environment": "production"}, "Ready", "Task complete", "session"), (200, {}))
            routing.update(scheduleId="b234f19f-24b3-4baf-8f73-931143a845e2", runId="84ed4ea7-48a2-493d-a6c1-fce316e3231d")
            self.assertEqual(await apns.send({"token": "a" * 64, "environment": "production"}, "Ready", "Task complete", "session", routing["scheduleId"], routing["runId"]), (200, {}))
        self.assertEqual(hosts, ["api.push.apple.com", "api.sandbox.push.apple.com", "api.sandbox.push.apple.com", "api.sandbox.push.apple.com"])
        expected = apns.notification_payload("Ready", "Task complete", "session", routing["scheduleId"], routing["runId"])
        self.assertEqual(apns.payload_size("Ready", "Task complete", "session", routing["scheduleId"], routing["runId"]), len(json.dumps(expected, separators=(",", ":")).encode()))
