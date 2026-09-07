import HTTPResponse from '../Networking/HTTPResponse.js'
import { pushDelivery } from '../Notifications/PushDelivery.js'

export function register(request) {
  const body = request.json()
  const token = request.headers['x-push-device-token'] || body.token
  if (typeof body.deviceId === 'string' && /^[A-Za-z0-9-]{1,128}$/u.test(body.deviceId) && typeof token === 'string' && /^[A-Fa-f0-9]{32,512}$/u.test(token) && ['sandbox', 'production'].includes(body.environment)) {
    const queued = pushDelivery.enqueue(`device:${body.deviceId}`, 'PUT', `/push-devices/${encodeURIComponent(body.deviceId)}`, { deviceId: body.deviceId, token, environment: body.environment, bundleId: 'soli.Cloude' })
    return HTTPResponse.json(queued ? 202 : 503, queued ? { ok: true } : { error: 'push_requires_provisioned_endpoint' })
  }
  return HTTPResponse.json(400, { error: 'invalid_push_device' })
}
