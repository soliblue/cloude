import unittest
import asyncio
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException, status

from app.api import push
from app.schemas.push import PushDeviceRequest


class PushTests(unittest.IsolatedAsyncioTestCase):
    async def test_scheduled_route_validation_and_delivery(self):
        route = {"sessionId": "b234f19f-24b3-4baf-8f73-931143a845e2", "scheduleId": "84ed4ea7-48a2-493d-a6c1-fce316e3231d", "runId": "6b3abc6c-65e5-4708-9585-9362e437c60e"}
        payload = {"eventId": "schedule-test", "title": "Scheduled task ready", "body": "Open its run history", **route}
        device = {"device_id": "fixture", "token": "a" * 64}
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.queries, "claim_notification", return_value=("claimed", "owner")), patch.object(push.queries, "renew_notification", return_value=True), patch.object(push.queries, "delivered_devices", return_value=set()), patch.object(push.queries, "mark_device_delivered", return_value=True), patch.object(push.queries, "push_devices", return_value=[device]), patch.object(push.queries, "complete_notification", return_value=True), patch.object(push.apns, "send", new=AsyncMock(return_value=(200, {}))) as send:
            self.assertEqual(await push.send_notification("mac", payload, "secret"), {"delivered": True})
            send.assert_awaited_once_with(device, payload["title"], payload["body"], route["sessionId"], schedule_id=route["scheduleId"], run_id=route["runId"])
        for key in route:
            for invalid in [None, "", "../wrong", 42]:
                with self.subTest(key=key, invalid=invalid), patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.queries, "claim_notification") as claim:
                    with self.assertRaises(HTTPException) as failure:
                        await push.send_notification("mac", {**payload, key: invalid}, "secret")
                    self.assertEqual(failure.exception.status_code, 400)
                    claim.assert_not_called()

    async def test_missing_configuration_is_explicit(self):
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=False):
            with self.assertRaisesRegex(HTTPException, "push delivery is not configured") as failure:
                await push.send_notification("mac", {"eventId": "event", "title": "Done", "body": "Ready"}, "secret")
        self.assertEqual(failure.exception.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)

    async def test_invalid_payload_is_rejected(self):
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True):
            with self.assertRaisesRegex(HTTPException, "eventId, title and body are required") as failure:
                await push.send_notification("mac", {"title": "Done"}, "secret")
        self.assertEqual(failure.exception.status_code, status.HTTP_400_BAD_REQUEST)

    async def test_auth_rejection_is_preserved(self):
        failure = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid mac credentials")
        with patch.object(push, "verify_mac", side_effect=failure):
            with self.assertRaises(HTTPException) as raised:
                await push.send_notification("mac", {"eventId": "event", "title": "Done", "body": "Ready"}, "secret")
        self.assertEqual(raised.exception.status_code, status.HTTP_401_UNAUTHORIZED)

    async def test_partial_failure_removes_event_for_daemon_retry(self):
        send = AsyncMock(side_effect=[(200, {}), (403, {})])
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.apns, "payload_size", return_value=100), patch.object(push.queries, "claim_notification", return_value=("claimed", "owner")), patch.object(push.queries, "renew_notification", return_value=True), patch.object(push.queries, "delivered_devices", return_value=set()), patch.object(push.queries, "mark_device_delivered", return_value=True), patch.object(push.queries, "push_devices", return_value=[{"device_id": "a", "token": "a"}, {"device_id": "b", "token": "b"}]), patch.object(push.queries, "forget_notification") as forget, patch.object(push.apns, "send", send):
            with self.assertRaisesRegex(HTTPException, "push delivery failed") as failure:
                await push.send_notification("mac", {"eventId": "event", "title": "Done", "body": "Ready"}, "secret")
        self.assertEqual(failure.exception.status_code, status.HTTP_502_BAD_GATEWAY)
        forget.assert_called_once_with("mac", "event", "owner")

    async def test_expired_token_is_deleted(self):
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.apns, "payload_size", return_value=100), patch.object(push.queries, "claim_notification", return_value=("claimed", "owner")), patch.object(push.queries, "renew_notification", return_value=True), patch.object(push.queries, "delivered_devices", return_value=set()), patch.object(push.queries, "push_devices", return_value=[{"device_id": "expired", "token": "expired"}]), patch.object(push.queries, "delete_push_token") as delete, patch.object(push.queries, "complete_notification", return_value=True), patch.object(push.apns, "send", new=AsyncMock(return_value=(410, {"reason": "Unregistered"}))):
            result = await push.send_notification("mac", {"eventId": "event", "title": "Done", "body": "Ready"}, "secret")
        self.assertEqual(result, {"delivered": True})
        delete.assert_called_once_with("mac", "expired")

    async def test_duplicate_event_is_idempotent(self):
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.queries, "claim_notification", return_value=("delivered", None)), patch.object(push.apns, "send", new=AsyncMock()) as send:
            result = await push.send_notification("mac", {"eventId": "event", "title": "Done", "body": "Ready"}, "secret")
        self.assertEqual(result, {"delivered": True, "duplicate": True})
        send.assert_not_awaited()

    async def test_partial_failure_retry_skips_delivered_device(self):
        send = AsyncMock(side_effect=[(200, {}), (503, {}), (200, {})])
        devices = [{"device_id": "a", "token": "a"}, {"device_id": "b", "token": "b"}]
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.apns, "payload_size", return_value=100), patch.object(push.queries, "claim_notification", side_effect=[("claimed", "owner"), ("claimed", "owner")]), patch.object(push.queries, "renew_notification", return_value=True), patch.object(push.queries, "delivered_devices", side_effect=[set(), {"a"}]), patch.object(push.queries, "mark_device_delivered", return_value=True), patch.object(push.queries, "push_devices", return_value=devices), patch.object(push.queries, "forget_notification"), patch.object(push.queries, "complete_notification", return_value=True), patch.object(push.apns, "send", send):
            with self.assertRaises(HTTPException):
                await push.send_notification("mac", {"eventId": "event", "title": "Done", "body": "Ready"}, "secret")
            result = await push.send_notification("mac", {"eventId": "event", "title": "Done", "body": "Ready"}, "secret")
        self.assertEqual(result, {"delivered": True})
        self.assertEqual([call.args[0]["device_id"] for call in send.await_args_list], ["a", "b", "b"])

    async def test_event_id_is_scoped_to_mac(self):
        send = AsyncMock(return_value=(200, {}))
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.apns, "payload_size", return_value=100), patch.object(push.queries, "claim_notification", side_effect=[("claimed", "owner-a"), ("claimed", "owner-b")]), patch.object(push.queries, "renew_notification", return_value=True), patch.object(push.queries, "delivered_devices", return_value=set()), patch.object(push.queries, "mark_device_delivered", return_value=True), patch.object(push.queries, "push_devices", return_value=[{"device_id": "device", "token": "token"}]), patch.object(push.queries, "complete_notification", return_value=True), patch.object(push.apns, "send", send):
            await push.send_notification("mac-a", {"eventId": "same", "title": "Done", "body": "Ready"}, "secret")
            await push.send_notification("mac-b", {"eventId": "same", "title": "Done", "body": "Ready"}, "secret")
        self.assertEqual([call.args[:2] for call in send.await_args_list], [({"device_id": "device", "token": "token"}, "Done"), ({"device_id": "device", "token": "token"}, "Done")])

    async def test_concurrent_event_returns_conflict_without_double_send(self):
        send = AsyncMock(return_value=(200, {}))
        claim = [("claimed", "owner"), ("busy", None)]
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.apns, "payload_size", return_value=100), patch.object(push.queries, "claim_notification", side_effect=lambda *args: claim.pop(0)), patch.object(push.queries, "delivered_devices", return_value=set()), patch.object(push.queries, "mark_device_delivered", return_value=True), patch.object(push.queries, "renew_notification", return_value=True), patch.object(push.queries, "push_devices", return_value=[{"device_id": "device", "token": "token"}]), patch.object(push.queries, "complete_notification", return_value=True), patch.object(push.apns, "send", send):
            results = await asyncio.gather(
                push.send_notification("mac", {"eventId": "same", "title": "Done", "body": "Ready"}, "secret"),
                push.send_notification("mac", {"eventId": "same", "title": "Done", "body": "Ready"}, "secret"),
                return_exceptions=True,
            )
        self.assertEqual(sum(isinstance(result, HTTPException) and result.status_code == status.HTTP_409_CONFLICT for result in results), 1)
        self.assertEqual(send.await_count, 1)

    async def test_registration_rejects_wrong_bundle(self):
        with patch.object(push, "verify_mac"), patch.object(push.apns, "topic", return_value="soli.Cloude"), patch.object(push.queries, "upsert_push_device") as upsert:
            with self.assertRaisesRegex(HTTPException, "unsupported app bundle"):
                push.put_push_device("mac", "device", PushDeviceRequest(deviceId="device", token="a" * 64, environment="sandbox", appBundleId="other.App"), "secret")
        upsert.assert_not_called()

    async def test_payload_size_is_rejected_before_claim(self):
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.queries, "claim_notification") as claim:
            with self.assertRaisesRegex(HTTPException, "payload is too large"):
                await push.send_notification("mac", {"eventId": "event", "title": "Done", "body": "x" * 2049}, "secret")
        claim.assert_not_called()

    async def test_lease_loss_stops_before_sending_next_device(self):
        send = AsyncMock(return_value=(200, {}))
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.apns, "payload_size", return_value=100), patch.object(push.queries, "claim_notification", return_value=("claimed", "owner")), patch.object(push.queries, "renew_notification", side_effect=[True, False]), patch.object(push.queries, "delivered_devices", return_value=set()), patch.object(push.queries, "mark_device_delivered", return_value=True), patch.object(push.queries, "push_devices", return_value=[{"device_id": "a", "token": "a"}, {"device_id": "b", "token": "b"}]), patch.object(push.queries, "forget_notification"), patch.object(push.apns, "send", send):
            with self.assertRaisesRegex(HTTPException, "push delivery failed"):
                await push.send_notification("mac", {"eventId": "event", "title": "Done", "body": "Ready"}, "secret")
        self.assertEqual(send.await_count, 1)

    async def test_session_id_size_is_rejected_before_claim(self):
        with patch.object(push, "verify_mac"), patch.object(push.apns, "configured", return_value=True), patch.object(push.queries, "claim_notification") as claim:
            with self.assertRaisesRegex(HTTPException, "sessionId is too large"):
                await push.send_notification("mac", {"eventId": "event", "title": "Done", "body": "Ready", "sessionId": "x" * 257}, "secret")
        claim.assert_not_called()
