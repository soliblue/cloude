#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
for suite in ./run-*-tests.sh; do
    "$suite"
done
