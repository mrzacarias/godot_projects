# Helper Scripts

This directory contains utility scripts for the Survive 30 Days game project.

## Audio Processing Scripts

### `normalize_audio.sh`
**Recommended** - Normalizes all MP3 files in the sounds directory using EBU R128 loudness standard.
- Target: -23 LUFS (ideal for games)
- Creates backups of original files
- Ensures consistent perceived loudness across all sounds

Usage:
```bash
cd helpers
./normalize_audio.sh
```

### `normalize_audio_simple.sh`
Simple peak normalization for MP3 files.
- Normalizes to peak levels
- Simpler but less consistent than loudness normalization

Usage:
```bash
cd helpers
./normalize_audio_simple.sh
```

### `analyze_audio.sh`
Analyzes current loudness levels of all MP3 files before processing.
- Shows Input Integrated Loudness, True Peak, and LRA values
- Useful for understanding current audio levels

Usage:
```bash
cd helpers
./analyze_audio.sh
```

## Development Scripts

### `check_errors.sh`
Validates GDScript files and reports errors/warnings in the project.
- Checks individual GDScript files for syntax errors
- Provides detailed error reporting
- Uses Godot's built-in script validation
- Now uses relative paths (works from helpers directory)

Usage:
```bash
cd helpers
./check_errors.sh
```

**Prerequisites:** Requires Godot executable at `/Applications/Godot.app/Contents/MacOS/Godot` (update the GODOT_EXECUTABLE path in the script if your Godot installation is elsewhere).

## Prerequisites

All audio scripts require FFmpeg:
```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt install ffmpeg
```
