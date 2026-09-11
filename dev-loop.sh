#!/bin/bash
# Fast dev loop: build -> relaunch app -> allow GPS/network startup -> screenshot.
# Usage: ./dev-loop.sh [shot-name]
# Env: LD_LIBRARY_PATH must include webkit libs (exported below).
set -e
cd /home/d/code/garmin-nyc-mta
export LD_LIBRARY_PATH=/home/d/code/.webkit/libs
export DISPLAY=:0
SHOT=${1:-shot}

monkeyc -d fr965 -f monkey.jungle -o build/NycMta.prg -y /home/d/.garmin/developer_key.der | head -3

for p in $(pgrep -f MonkeyDoDeux); do
  if [ "$p" != "$$" ]; then kill -9 "$p" 2>/dev/null || true; fi
done
sleep 1
setsid nohup stdbuf -o0 -e0 monkeydo build/NycMta.prg fr965 > /tmp/app.log 2>&1 < /dev/null &
echo $! > /tmp/mta-app.pid

# Allow the app GPS/network watchdog to settle; inspect the screenshot for success.
# No laptop proxy/log is required with the hosted default.
sleep 30
wmctrl -a "CIQ Simulator"
gnome-screenshot -w -f /tmp/${SHOT}.png
python3 -c "
from PIL import Image
im = Image.open('/tmp/${SHOT}.png')
w, h = im.size
im.crop((int(w*0.05), int(h*0.07), int(w*0.95), int(h*0.97))).save('/tmp/${SHOT}.png')
print('shot ok')
"
