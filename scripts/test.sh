#!/bin/bash
# Runs the unit tests. With only Command Line Tools installed, swiftc cannot find the Swift Testing macro plugin on its own.
# Serial on purpose: the tunnel and local-server tests wait on sockets and timers, and starve each other when run in parallel (CI does the same).
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGINS="$(dirname "$(xcrun --find swiftc)")/../lib/swift/host/plugins/testing"
if [ -d "$PLUGINS" ]; then
  exec swift test --no-parallel -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
fi
exec swift test --no-parallel "$@"
