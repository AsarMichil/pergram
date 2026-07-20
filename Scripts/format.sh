#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcrun swift-format format --in-place --recursive --parallel \
    --configuration .swift-format \
    pergram pergramTests pergramUITests
