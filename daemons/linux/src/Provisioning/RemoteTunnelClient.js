const provisioningURL = process.env.CLOUDE_PROVISIONING_URL || 'https://remotecc.soli.blue'

export async function putMac(identity, displayName) {
  const response = await fetch(`${provisioningURL}/macs/${identity.installationId}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'X-Mac-Secret': identity.secret,
      'User-Agent': 'CloudeLinuxDaemon/1',
    },
    body: JSON.stringify({ displayName }),
  })
  return response.ok
}

export async function putTunnel(identity) {
  const response = await fetch(`${provisioningURL}/macs/${identity.installationId}/tunnel`, {
    method: 'PUT',
    headers: {
      'X-Mac-Secret': identity.secret,
      'User-Agent': 'CloudeLinuxDaemon/1',
    },
  })
  if (response.ok) {
    return await response.json()
  }
  return null
}
