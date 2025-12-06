#!/bin/bash

# Godot Error Checker Script
# This script validates GDScript files and reports errors/warnings

# Get the project directory (parent of helpers directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GODOT_EXECUTABLE="/Applications/Godot.app/Contents/MacOS/Godot"
LOG_FILE="/tmp/godot_check_$(date +%s).log"

echo "🔍 Checking Godot project for errors and warnings..."
echo "Project: $PROJECT_DIR"
echo "=========================================="

# Check if Godot executable exists
if [ ! -f "$GODOT_EXECUTABLE" ]; then
    echo "❌ Godot executable not found at: $GODOT_EXECUTABLE"
    echo "Please update the GODOT_EXECUTABLE path in this script"
    exit 1
fi

# Change to project directory
cd "$PROJECT_DIR" || exit 1

# Function to run command with timeout
run_with_timeout() {
    local timeout_duration=$1
    local command="$2"
    local output_file="$3"
    
    # Run command in background
    eval "$command" > "$output_file" 2>&1 &
    local pid=$!
    
    # Wait for completion or timeout
    local count=0
    while kill -0 $pid 2>/dev/null && [ $count -lt $timeout_duration ]; do
        sleep 1
        count=$((count + 1))
    done
    
    # Kill if still running
    if kill -0 $pid 2>/dev/null; then
        kill -TERM $pid 2>/dev/null
        sleep 2
        kill -KILL $pid 2>/dev/null
        echo "Command timed out after ${timeout_duration}s" >> "$output_file"
        return 1
    fi
    
    wait $pid
    return $?
}

# Check individual GDScript files first (faster and more reliable)
echo "🔍 Checking individual GDScript files..."
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
CHECKED_FILES=0

# Key files to check
KEY_FILES=(
    "game.gd"
    "player.gd" 
    "objects/boss.gd"
    "objects/mob.gd"
    "BaseEnemy.gd"
    "GameConstants.gd"
    "PlayerMovement.gd"
    "PhysicsOptimizer.gd"
)

echo "Checking key files:"
for file in "${KEY_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -n "  Checking $file... "
        if "$GODOT_EXECUTABLE" --headless --check-only --script "$file" >/dev/null 2>&1; then
            echo "✅"
        else
            echo "❌"
            echo "    Error details:"
            "$GODOT_EXECUTABLE" --headless --check-only --script "$file" 2>&1 | sed 's/^/    /'
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
        CHECKED_FILES=$((CHECKED_FILES + 1))
    fi
done

echo ""
echo "Checking other .gd files:"
find . -name "*.gd" -type f | grep -v -E "($(IFS='|'; echo "${KEY_FILES[*]}"))" | while read -r file; do
    echo -n "  Checking $file... "
    if "$GODOT_EXECUTABLE" --headless --check-only --script "$file" >/dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
        echo "    Error details:"
        "$GODOT_EXECUTABLE" --headless --check-only --script "$file" 2>&1 | sed 's/^/    /'
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    CHECKED_FILES=$((CHECKED_FILES + 1))
done

echo ""
echo "=========================================="
echo "📊 Summary:"
echo "Files checked: $CHECKED_FILES"

# Clean up log file
rm -f "$LOG_FILE"

echo ""
echo "=========================================="
echo "📊 Final Summary:"
echo "Total errors found: $TOTAL_ERRORS"
echo "Total warnings found: $TOTAL_WARNINGS"

if [ "$TOTAL_ERRORS" -eq 0 ]; then
    echo "✅ No critical errors found! Project should compile successfully."
    if [ "$TOTAL_WARNINGS" -gt 0 ]; then
        echo "⚠️  Some warnings were found, but they won't prevent the game from running."
    fi
    exit 0
else
    echo "🔧 Please fix the errors above before running the game."
    exit 1
fi
