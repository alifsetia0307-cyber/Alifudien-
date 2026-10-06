#!/bin/bash
# Pasang alarm Morning English di macOS:  ./install.sh  [JAM:MENIT, default 03:00]
set -e
TIME=${1:-03:00}; HOUR=$((10#${TIME%%:*})); MIN=$((10#${TIME##*:}))
DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/Library/Application Support/MorningEnglish"
PLIST="$HOME/Library/LaunchAgents/com.morningenglish.alarm.plist"

mkdir -p "$APP_DIR" "$HOME/Library/LaunchAgents"
cp "$DIR/morning-english.sh" "$APP_DIR/"; chmod +x "$APP_DIR/morning-english.sh"
[ -f "$APP_DIR/sources.txt" ] || cp "$DIR/../sources.txt" "$APP_DIR/"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.morningenglish.alarm</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$APP_DIR/morning-english.sh</string></array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>$HOUR</integer><key>Minute</key><integer>$MIN</integer></dict>
</dict></plist>
EOF
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

# Wake the Mac one minute before the alarm (asks for your password)
WAKE=$(date -j -v-1M -f "%H:%M" "$TIME" +%H:%M:00)
sudo pmset repeat wakeorpoweron MTWRFSU "$WAKE"

echo "SELESAI. Alarm aktif setiap hari jam $TIME (Mac bangun jam $WAKE)."
echo "Sebelum tidur: biarkan Mac dalam keadaan SLEEP (jangan Shut Down) dan colokkan charger."
