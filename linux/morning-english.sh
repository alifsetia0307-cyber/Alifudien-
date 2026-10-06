#!/bin/bash
# Morning English Alarm (Linux, GNOME/KDE/XFCE): alarm sampai kamu MENGETIK kalimat English, lalu YouTube diputar.
# Dijalankan oleh systemd user timer jam 03:00 (lihat install.sh). Tes manual: ./morning-english.sh
# Butuh: zenity, curl, pulseaudio-utils (paplay/pactl) atau pipewire (wpctl)
ALARM_VOLUME=100; VIDEO_VOLUME=70; MAX_ALARM_MINUTES=15; STAY_AWAKE_MINUTES=${STAY_AWAKE_MINUTES:-90}
DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/morning-english"
SOURCES="$DIR/sources.txt"; [ -f "$SOURCES" ] || SOURCES="$DIR/../sources.txt"
mkdir -p "$APP_DIR"; LOG="$APP_DIR/log.txt"; STREAK="$APP_DIR/streak.txt"
log() { echo "$(date '+%F %T')  $*" >> "$LOG"; }
export DISPLAY=${DISPLAY:-:0}
log "=== Morning English started ==="

# Keep the laptop awake while you study
if [ -z "$MORNING_INHIBITED" ]; then
  export MORNING_INHIBITED=1
  exec systemd-inhibit --what=sleep:idle --why="Morning English" "$0" "$@"
fi

set_volume() {
  if command -v wpctl >/dev/null; then wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ "$1%"
  else pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ "$1%"; fi
}
set_volume "$ALARM_VOLUME"

# ---- today's source (rotates daily)
LINES=$(grep -v '^[[:space:]]*#' "$SOURCES" 2>/dev/null | grep -v '^[[:space:]]*$'); COUNT=$(echo "$LINES" | grep -c .)
if [ "$COUNT" -gt 0 ]; then
  LINE=$(echo "$LINES" | sed -n "$(( 10#$(date +%j) % COUNT + 1 ))p")
else
  LINE="BBC Learning English | https://www.youtube.com/@bbclearningenglish/videos"
fi
NAME=$(echo "${LINE%%|*}" | xargs); URL=$(echo "${LINE#*|}" | xargs)
log "Today's source: $NAME $URL"

# ---- alarm loop
SOUND=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
( while true; do paplay "$SOUND" 2>/dev/null || { printf '\a'; sleep 1; }; done ) & ALARM_PID=$!

SENTENCES=("I am awake and ready to learn English" "Today I will speak English with confidence"
  "Small steps every morning build a strong habit" "I choose discipline over comfort today"
  "My future self will thank me for this morning")
TARGET=${SENTENCES[$(( 10#$(date +%j) % ${#SENTENCES[@]} ))]}
norm() { echo "$1" | tr -cd 'a-zA-Z ' | tr -s ' ' | tr 'A-Z' 'a-z' | xargs; }

RESULT=timeout; END=$(( $(date +%s) + MAX_ALARM_MINUTES * 60 ))
while [ "$(date +%s)" -lt "$END" ]; do
  ANSWER=$(zenity --entry --title="Morning English" --width=700 --timeout=60 \
    --text="GOOD MORNING! It's $(date +%H:%M)\n\nType this sentence to stop the alarm:\n\n<b>$TARGET</b>\n\nNext: $NAME" 2>/dev/null)
  if [ "$(norm "$ANSWER")" = "$(norm "$TARGET")" ]; then RESULT=dismissed; break; fi
done
kill "$ALARM_PID" 2>/dev/null; pkill -P "$ALARM_PID" 2>/dev/null
log "Alarm closed: $RESULT"

# ---- video
set_volume "$VIDEO_VOLUME"
if ! echo "$URL" | grep -qE '/watch\?|youtu\.be/|/live'; then
  ID=$(curl -sL -m 20 -H 'Accept-Language: en-US,en' "$URL" | grep -oE '"videoId":"[A-Za-z0-9_-]{11}"' | head -1 | cut -d'"' -f4)
  if [ -n "$ID" ]; then URL="https://www.youtube.com/watch?v=$ID"
  else URL="https://www.youtube.com/results?search_query=$(echo "$NAME" | sed 's/ /+/g')"; fi
fi
BROWSER=$(command -v google-chrome || command -v chromium || command -v chromium-browser || command -v microsoft-edge)
if [ -n "$BROWSER" ]; then
  "$BROWSER" --user-data-dir="$APP_DIR/browser" --autoplay-policy=no-user-gesture-required \
    --no-first-run --start-maximized --new-window "$URL" >/dev/null 2>&1 &
else
  xdg-open "$URL" >/dev/null 2>&1 &
fi
log "Opened $URL"

if [ "$RESULT" = dismissed ]; then
  TODAY=$(date +%F); grep -qx "$TODAY" "$STREAK" 2>/dev/null || echo "$TODAY" >> "$STREAK"
  N=0; while grep -qx "$(date -d "-$N day" +%F)" "$STREAK"; do N=$((N + 1)); done
  log "Streak: $N"
  notify-send "Nice! Morning English" "Streak: $N day(s) in a row. Repeat 3 sentences out loud!" 2>/dev/null
fi

sleep $(( STAY_AWAKE_MINUTES * 60 ))
log "=== Morning English finished ==="
