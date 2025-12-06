#!/bin/sh
set -e

echo "=== Building Project ==="
lake build

echo "\n=== Running Unit Tests ==="
lake env lean --run Tests.lean

echo "\n=== Running Example (Integration Test) ==="
# This runs the compiled binary which hits example.com
./.lake/build/bin/http-client

echo "\n=== All Tests Passed ==="

