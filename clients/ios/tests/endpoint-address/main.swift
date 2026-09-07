import Foundation

let local = EndpointAddress(input: "  devbox.local  ")!
precondition(local.host == "devbox.local" && local.port == 8765 && local.scheme == "http")
let secure = EndpointAddress(input: "https://example.com:8443/", port: 8765)!
precondition(secure.host == "example.com" && secure.port == 8443 && secure.scheme == "https")
let standard = EndpointAddress(input: "https://example.com")!
precondition(standard.port == 443)
let explicitHTTP = EndpointAddress(input: "http://example.com:443")!
precondition(explicitHTTP.scheme == "http")
let legacy = EndpointAddress(input: "example.com", port: 443)!
precondition(legacy.scheme == "https")
let ipv6 = EndpointAddress(input: "::1")!
precondition(ipv6.host == "[::1]" && ipv6.port == 8765)
let ipv6TLS = EndpointAddress(input: "https://[2001:db8::1]:8443")!
precondition(ipv6TLS.host == "[2001:db8::1]" && ipv6TLS.port == 8443)
precondition(EndpointAddress(input: "example.com:9000")?.port == 9000)
for input in ["", "file:///etc/passwd", "ftp://example.com", "https://user:password@example.com", "https://example.com/api", "https://example.com?key=secret", "https://example.com#fragment", "https://example.com:70000", "https://example.com:0", "some host"] {
    precondition(EndpointAddress(input: input) == nil, input)
}
let pair = OnboardingPairingPayload(url: URL(string: "afto://pair?host=example.com&port=8443&scheme=https&token=test")!)!
precondition(pair.host == "example.com" && pair.port == 8443 && pair.scheme == "https")
precondition(OnboardingPairingPayload(url: URL(string: "cloude://pair?host=example.com&port=invalid&token=test")!) == nil)
print("PASS: copied HTTPS URLs, custom TLS ports, IPv6, legacy port443, unsafe/invalid URL rejection and pairing scheme")
