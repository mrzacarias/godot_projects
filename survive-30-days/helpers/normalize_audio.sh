#!/bin/bash

# Audio normalization script for game sounds
# This script normalizes all MP3 files to a consistent loudness level

SOUNDS_DIR="/Users/mrzacarias/go/src/github.com/mrzacarias/godot_projects/survive-30-days/assets/sounds"
BACKUP_DIR="${SOUNDS_DIR}/backup_original"
TARGET_LUFS="-23"  # Target loudness in LUFS (good for games)

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Starting audio normalization process..."
echo "Target loudness: ${TARGET_LUFS} LUFS"
echo "Backup directory: $BACKUP_DIR"
echo ""

# Function to normalize a single file
normalize_file() {
    local input_file="$1"
    local filename=$(basename "$input_file")
    local backup_file="${BACKUP_DIR}/${filename}"
    local temp_file="${input_file}.temp.mp3"
    
    echo "Processing: $filename"
    
    # Create backup
    cp "$input_file" "$backup_file"
    
    # Normalize audio using loudnorm filter
    ffmpeg -i "$input_file" \
           -af "loudnorm=I=${TARGET_LUFS}:TP=-1.5:LRA=11:print_format=summary" \
           -c:a libmp3lame \
           -b:a 192k \
           "$temp_file" \
           -y -loglevel warning
    
    if [ $? -eq 0 ]; then
        mv "$temp_file" "$input_file"
        echo "✓ Normalized: $filename"
    else
        rm -f "$temp_file"
        echo "✗ Failed: $filename"
    fi
    echo ""
}

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: FFmpeg is not installed."
    echo "Please install FFmpeg first:"
    echo "  macOS: brew install ffmpeg"
    echo "  Ubuntu/Debian: sudo apt install ffmpeg"
    echo "  Windows: Download from https://ffmpeg.org/"
    exit 1
fi

# Process all MP3 files
cd "$SOUNDS_DIR"
for file in *.mp3; do
    if [ -f "$file" ]; then
        normalize_file "$file"
    fi
done

echo "Audio normalization complete!"
echo "Original files backed up to: $BACKUP_DIR"
echo ""
echo "Summary:"
echo "- All MP3 files normalized to ${TARGET_LUFS} LUFS"
echo "- Original files backed up"
echo "- You can now test the normalized audio in your game"
