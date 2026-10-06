#!/bin/bash
# Morning English Alarm (macOS): alarm sampai kamu MENGETIK kalimat English, lalu YouTube diputar.
# Dijalankan oleh launchd jam 03:00 (lihat install.sh). Tes manual: ./morning-english.sh
ALARM_VOLUME=100; VIDEO_VOLUME=70; MAX_ALARM_MINUTES=15; STAY_AWAKE_MINUTES=${STAY_AWAKE_MINUTES:-90}
DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/Library/Application Support/MorningEnglish"
SOURCES="$DIR/sources.txt"; [ -f "$SOURCES" ] || SOURCES="$DIR/../sources.txt"
mkdir -p "$APP_DIR"; LOG="$APP_DIR/log.txt"; STREAK="$APP_DIR/streak.txt"
log() { echo "$(date '+%F %T')  $*" >> "$LOG"; }
log "=== Morning English started ==="

# Keep the Mac (and screen) awake while you study
caffeinate -dimsu -t $(( (MAX_ALARM_MINUTES + STAY_AWAKE_MINUTES) * 60 + 60 )) &
osascript -e "set volume output volume $ALARM_VOLUME without output muted"

# ---- today's source (rotates daily)
mapfile_compat() { grep -v '^[[:space:]]*#' "$SOURCES" 2>/dev/null | grep -v '^[[:space:]]*$'; }
LINES=$(mapfile_compat); COUNT=$(echo "$LINES" | grep -c .)
if [ "$COUNT" -gt 0 ]; then
  LINE=$(echo "$LINES" | sed -n "$(( 10#$(date +%j) % COUNT + 1 ))p")
else
  LINE="BBC Learning English | https://www.youtube.com/@bbclearningenglish/videos"
fi
NAME=$(echo "${LINE%%|*}" | xargs); URL=$(echo "${LINE#*|}" | xargs)
log "Today's source: $NAME $URL"

# ---- alarm loop
SOUND=/System/Library/Sounds/Glass.aiff
( while true; do afplay "$SOUND"; done ) & ALARM_PID=$!

SENTENCES=("I am awake and ready to learn English" "Today I will speak English with confidence"
  "Small steps every morning build a strong habit" "I choose discipline over comfort today"
  "My future self will thank me for this morning")
TARGET=${SENTENCES[$(( 10#$(date +%j) % ${#SENTENCES[@]} ))]}
norm() { echo "$1" | tr -cd 'a-zA-Z ' | tr -s ' ' | tr 'A-Z' 'a-z' | xargs; }

RESULT=timeout; END=$(( $(date +%s) + MAX_ALARM_MINUTES * 60 ))
while [ "$(date +%s)" -lt "$END" ]; do
  ANSWER=$(osascript -e "text returned of (display dialog \"GOOD MORNING! It's $(date +%H:%M)\n\nType this sentence to stop the alarm:\n\n$TARGET\n\nNext: $NAME\" default answer \"\" buttons {\"OK\"} default button 1 giving up after 60 with title \"Morning English\")" 2>/dev/null)
  if [ "$(norm "$ANSWER")" = "$(norm "$TARGET")" ]; then RESULT=dismissed; break; fi
done
kill "$ALARM_PID" 2>/dev/null; pkill -P "$ALARM_PID" 2>/dev/null; killall afplay 2>/dev/null
log "Alarm closed: $RESULT"

# ---- video
osascript -e "set volume output volume $VIDEO_VOLUME"
if ! echo "$URL" | grep -qE '/watch\?|youtu\.be/|/live'; then
  ID=$(curl -sL -m 20 -H 'Accept-Language: en-US,en' "$URL" | grep -oE '"videoId":"[A-Za-z0-9_-]{11}"' | head -1 | cut -d'"' -f4)
  if [ -n "$ID" ]; then URL="https://www.youtube.com/watch?v=$ID"
  else URL="https://www.youtube.com/results?search_query=$(echo "$NAME" | sed 's/ /+/g')"; fi
fi
if [ -d "/Applications/Google Chrome.app" ]; then
  open -na "Google Chrome" --args --user-data-dir="$APP_DIR/browser" --autoplay-policy=no-user-gesture-required \
    --no-first-run --start-maximized --new-window "$URL"
else
  open "$URL"
fi
log "Opened $URL"

if [ "$RESULT" = dismissed ]; then
  TODAY=$(date +%F); grep -qx "$TODAY" "$STREAK" 2>/dev/null || echo "$TODAY" >> "$STREAK"
  N=0; while grep -qx "$(date -v-${N}d +%F)" "$STREAK"; do N=$((N + 1)); done
  log "Streak: $N"
  osascript -e "display notification \"Streak: $N day(s) in a row. Repeat 3 sentences out loud!\" with title \"Nice! Morning English\""
fi
log "=== Morning English finished ==="
