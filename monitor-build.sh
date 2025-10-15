#!/bin/bash
# Monitor Chromium build progress in Docker container

CONTAINER_ID="ab34486e5360"

echo "=== Chromium Build Monitor ==="
echo ""

# Check if ninja is running
NINJA_PID=$(docker exec $CONTAINER_ID pgrep -f "ninja.*chrome" 2>/dev/null)
if [ -z "$NINJA_PID" ]; then
    echo "❌ Ninja is not running"
    exit 1
fi

echo "✅ Ninja is running (PID: $NINJA_PID)"
echo ""

# Get ninja progress
PROGRESS=$(docker exec -u builder -w /work/src/chromium-140.0.7339.207 $CONTAINER_ID \
    bash -c "ninja -C out/Release -t query chrome 2>&1 | head -5" 2>/dev/null || echo "Progress unavailable")

echo "Progress information:"
echo "$PROGRESS"
echo ""

# Count compiled targets from .ninja_log
COMPILED=$(docker exec -u builder -w /work $CONTAINER_ID \
    bash -c "wc -l < src/chromium-140.0.7339.207/out/Release/.ninja_log" 2>/dev/null || echo "0")
TOTAL=52859
PERCENT=$(echo "scale=2; ($COMPILED / $TOTAL) * 100" | bc 2>/dev/null || echo "0")

echo "Compiled targets: $COMPILED / $TOTAL (~${PERCENT}%)"
echo ""

# Show CPU and memory usage
echo "Resource usage:"
docker exec $CONTAINER_ID bash -c "ps aux | grep 'ninja.*chrome' | grep -v grep | awk '{print \"  CPU: \" \$3 \"%, MEM: \" \$4 \"%, RSS: \" \$6/1024 \" MB\"}'"
echo ""

# Show last 3 compiled files
echo "Recently compiled:"
docker exec -u builder -w /work $CONTAINER_ID \
    bash -c "tail -3 src/chromium-140.0.7339.207/out/Release/.ninja_log 2>/dev/null | awk '{print \"  \" \$4}'"
echo ""

# Estimate remaining time (very rough)
ELAPSED=$(docker exec $CONTAINER_ID bash -c "ps -p $NINJA_PID -o etimes= | tr -d ' '")
if [ "$COMPILED" -gt 0 ] && [ "$ELAPSED" -gt 0 ]; then
    RATE=$(echo "scale=2; $COMPILED / $ELAPSED" | bc)
    REMAINING=$(echo "scale=0; ($TOTAL - $COMPILED) / $RATE" | bc)
    REMAINING_HOURS=$(echo "scale=1; $REMAINING / 3600" | bc)
    echo "Estimated remaining time: ~${REMAINING_HOURS} hours (rough estimate)"
fi
