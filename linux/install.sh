#!/bin/bash
# Pasang alarm Morning English di Linux (systemd):  ./install.sh  [JAM:MENIT, default 03:00]
set -e
TIME=${1:-03:00}
DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/morning-english"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
WAKE=$(date -d "$TIME 1 minute ago" +%H:%M)

mkdir -p "$APP_DIR" "$UNIT_DIR"
cp "$DIR/morning-english.sh" "$APP_DIR/"; chmod +x "$APP_DIR/morning-english.sh"
[ -f "$APP_DIR/sources.txt" ] || cp "$DIR/../sources.txt" "$APP_DIR/"

# 1. User timer: runs the alarm inside your desktop session
cat > "$UNIT_DIR/morning-english.service" <<EOF
[Unit]
Description=Morning English alarm
[Service]
Type=simple
ExecStart=$APP_DIR/morning-english.sh
EOF
cat > "$UNIT_DIR/morning-english.timer" <<EOF
[Unit]
Description=Morning English alarm every day at $TIME
[Timer]
OnCalendar=*-*-* $TIME:00
[Install]
WantedBy=timers.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now morning-english.timer

# 2. System timer: wakes the laptop from sleep one minute earlier (needs sudo)
sudo tee /etc/systemd/system/morning-english-wake.service >/dev/null <<EOF
[Unit]
Description=Wake up for Morning English
[Service]
Type=oneshot
ExecStart=/bin/true
EOF
sudo tee /etc/systemd/system/morning-english-wake.timer >/dev/null <<EOF
[Unit]
Description=Wake the laptop for Morning English
[Timer]
OnCalendar=*-*-* $WAKE:00
WakeSystem=true
[Install]
WantedBy=timers.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now morning-english-wake.timer

echo "SELESAI. Alarm aktif setiap hari jam $TIME (laptop dibangunkan jam $WAKE)."
echo "Sebelum tidur: pakai SUSPEND/Sleep (jangan Shut Down) dan colokkan charger."
echo "Tes sekarang: systemctl --user start morning-english.service"
