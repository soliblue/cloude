#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc src/Features/Endpoints/Logic/EndpointAddress.swift src/Features/Onboarding/Logic/OnboardingPairingPayload.swift tests/endpoint-address/main.swift -o "$test_dir/endpoint-address-tests"
"$test_dir/endpoint-address-tests"
