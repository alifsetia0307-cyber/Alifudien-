# ☀️ Morning English Alarm

Setiap hari jam **03:00** laptop akan:

1. **Bangun sendiri** dari mode Sleep dan menyalakan layar
2. **Volume dinaikkan ke 100%** (speaker otomatis tidak di-mute)
3. **Alarm berbunyi terus.** Alarm hanya berhenti kalau kamu **mengetik satu kalimat bahasa Inggris** di layar.
   Tidak bisa ditutup dengan Esc / Alt+F4, jadi kamu tidak bisa mematikannya sambil setengah tidur.
4. **YouTube langsung diputar**: video terbaru dari BBC Learning English, BBC News, English with Lucy, VOA, atau TED-Ed (bergantian tiap hari)
5. **Streak** dihitung: "Streak: 12 day(s) in a row" 🔥 (bagus untuk motivasi ADHD)
6. Laptop **dijaga tetap menyala selama 90 menit** supaya tidak tidur lagi di tengah video

> Kalau alarm tidak dimatikan dalam 15 menit, alarm berhenti dan video **tetap diputar** sebagai cadangan.

---

## 🪟 Windows (paling umum)

1. Download repo ini (tombol hijau **Code → Download ZIP**), lalu extract
2. Buka folder `windows`, **klik dua kali `INSTALL.bat`**, lalu klik **Yes** saat diminta izin Administrator
3. Tes langsung: **klik dua kali `test-now.bat`**. Alarm harus berbunyi dan YouTube terbuka.

Ganti jam (misalnya 04:30): buka PowerShell di folder `windows`, lalu jalankan
`powershell -ExecutionPolicy Bypass -File install.ps1 -Time 04:30`

Hapus semuanya: klik dua kali `UNINSTALL.bat`

## 🍎 macOS

```bash
cd macos && ./install.sh          # atau ./install.sh 04:30
```
Kalau ditanya, beri izin *Terminal / osascript* untuk mengontrol "System Events".

## 🐧 Linux (Ubuntu/Fedora dengan systemd)

```bash
sudo apt install zenity curl pulseaudio-utils   # (Ubuntu)
cd linux && ./install.sh          # atau ./install.sh 04:30
```

---

## ⚠️ WAJIB: kebiasaan sebelum tidur (checklist)

Script ini bisa membangunkan laptop dari **Sleep**, tapi **tidak bisa dari Shut Down**.

- [ ] Colokkan **charger**
- [ ] Pilih **Sleep** (Start → Power → Sleep). **Jangan Shut down.**
- [ ] Biarkan **layar laptop terbuka** (atau atur: Control Panel → Power Options → *"When I close the lid" → Do nothing*)
- [ ] Speaker menyala, volume speaker fisik tidak di 0

Supaya tidak perlu memasukkan PIN/password jam 3 pagi (opsional, Windows):
Settings → Accounts → Sign-in options → *"If you've been away, when should Windows require you to sign in again?"* → **Never**.
Tanpa langkah ini, alarm dan suara **tetap berbunyi**, tapi kamu harus memasukkan PIN dulu untuk melihat layarnya.

## ✏️ Ganti video / channel

Edit file `sources.txt` (Windows: `%LOCALAPPDATA%\MorningEnglish\sources.txt`).
Satu baris = satu sumber, formatnya `Nama | URL`:

```
BBC Learning English | https://www.youtube.com/@bbclearningenglish/videos
My favourite video   | https://www.youtube.com/watch?v=XXXXXXXXXXX
```

URL channel (`.../videos`) → yang diputar otomatis **video terbaru**. URL `watch?v=` → diputar persis video itu.

## 🔧 Kalau tidak jalan

| Masalah | Solusi |
|---|---|
| Laptop tidak bangun | Pastikan Sleep (bukan Shut down/Hibernate) dan charger tercolok. Windows: Task Scheduler → `MorningEnglish` → Conditions → "Wake the computer to run this task" harus dicentang. Beberapa laptop juga perlu *Wake timers* diaktifkan di BIOS. |
| Tidak ada suara | Cek speaker yang dipilih sebagai default playback device. |
| Video tidak otomatis play | Klik sekali di video. Browser khusus alarm memakai profil terpisah, jadi login YouTube di profil itu tidak memengaruhi browser utamamu. |
| Lihat log | Windows: `%LOCALAPPDATA%\MorningEnglish\log.txt` · macOS: `~/Library/Application Support/MorningEnglish/log.txt` · Linux: `~/.local/share/morning-english/log.txt` |

## 💡 Tips ADHD: rutinitas 20 menit setelah alarm

1. Ketik kalimatnya **dan ucapkan keras-keras**
2. Minum segelas air (siapkan di samping laptop sebelum tidur)
3. Dengarkan video sambil berdiri atau jalan di tempat
4. **Shadowing**: pause, lalu ulangi 3 kalimat dari video dengan suara keras
5. Tulis 1 kata baru di buku catatan

Jangan putus streak-nya! 🔥
