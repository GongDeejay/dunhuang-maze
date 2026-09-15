#!/bin/bash
# Run headless tests for 敦煌迷途
# Usage: ./run_tests.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-godot}"

echo "=== 敦烷迷途 测试 ==="
echo "Using Godot: $GODOT"

# Find Godot binary
if ! command -v "$GODOT" &> /dev/null; then
    for candidate in \
        "/Users/gongdj/Downloads/Godot.app/Contents/MacOS/Godot" \
        "/Applications/Godot.app/Contents/MacOS/Godot" \
        "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
        if [ -x "$candidate" ]; then
            GODOT="$candidate"
            break
        fi
    done
fi

if ! command -v "$GODOT" &> /dev/null && [ ! -x "$GODOT" ]; then
    echo "ERROR: Godot not found. Set GODOT env var or install godot."
    echo "  brew install --cask godot"
    exit 1
fi

# Run headless tests
echo ""
echo "Running test suite..."
TEST_LOG=$(mktemp "${TMPDIR:-/tmp}/dunhuang-tests.XXXXXX") || exit 1
"$GODOT" --headless --path "$SCRIPT_DIR" res://tests/test_runner.tscn > "$TEST_LOG" 2>&1
EXIT_CODE=$?
cat "$TEST_LOG"
if grep -q 'SCRIPT ERROR:' "$TEST_LOG" || ! grep -Eq '测试完成: [0-9]+ 通过, 0 失败' "$TEST_LOG"; then
    EXIT_CODE=1
fi
rm "$TEST_LOG"

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "All tests passed!"
else
    echo "Some tests failed (exit code: $EXIT_CODE)"
fi

exit $EXIT_CODE
