#!/bin/bash
# Run headless tests for 敦煌迷途
# Usage: ./run_tests.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-godot}"

echo "=== 敦烷迷途 测试 ==="
echo "Using Godot: $GODOT"

# Find Godot binary
if ! command -v "$GODOT" &> /dev/null; then
    echo "ERROR: Godot not found. Set GODOT env var or install godot."
    echo "  brew install --cask godot"
    exit 1
fi

# Run headless tests
echo ""
echo "Running test suite..."
"$GODOT" --headless --path "$SCRIPT_DIR" -s tests/test_runner.gd 2>&1
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "All tests passed!"
else
    echo "Some tests failed (exit code: $EXIT_CODE)"
fi

exit $EXIT_CODE
