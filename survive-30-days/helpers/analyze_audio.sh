#!/bin/bash

# Audio analysis script - check current loudness levels
SOUNDS_DIR="/Users/mrzacarias/go/src/github.com/mrzacarias/godot_projects/survive-30-days/assets/sounds"

echo "Analyzing current audio levels..."
echo "=================================="

cd "$SOUNDS_DIR"
for file in *.mp3; do
    if [ -f "$file" ]; then
        echo "File: $file"
        ffmpeg -i "$file" -af "loudnorm=print_format=summary" -f null - 2>&1 | grep -E "(Input Integrated|Input True Peak|Input LRA)"
        echo ""
    fi
done
