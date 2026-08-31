#!/usr/bin/env bash
# Runs the python unit tests for the prefect driver via uv.
# Run: tests/prefect-unit.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
exec uv run --quiet --with "prefect>=3.8.4" --with pytest \
  python -m pytest prefect/tests -q
