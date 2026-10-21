#!/bin/bash
# Fast dev loop: build -> relaunch app -> allow GPS/network startup -> screenshot.
# Usage: ./dev-loop.sh [shot-name]
# Env: REPO_ROOT, GARMIN_WEBKIT_LIBS, DEVELOPER_KEY, DISPLAY, DEVICE.
# Optional Linux compatibility libraries: GARMIN_WEBKIT_LIBS defaults to
# $HOME/code/.webkit/libs; missing directories fall back to system libraries.
# Desktop-only helper: restarts MonkeyDo launchers and focuses the simulator.
# Agents must use a separate headless test display instead.
set -eo pipefail
REPO_ROOT=${REPO_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}
cd "$REPO_ROOT"
DEVICE=${DEVICE:-fr965}
mkdir -p build
GARMIN_WEBKIT_LIBS=${GARMIN_WEBKIT_LIBS:-$HOME/code/.webkit/libs}
if [ -d "$GARMIN_WEBKIT_LIBS" ]; then
  export LD_LIBRARY_PATH="$GARMIN_WEBKIT_LIBS${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
else
  printf 'Optional WebKit libraries not found at %s; using system libraries. Set GARMIN_WEBKIT_LIBS if the simulator needs compatibility libraries.\n' "$GARMIN_WEBKIT_LIBS" >&2
fi
export DISPLAY=${DISPLAY:-:0}
SHOT=${1:-shot}

# Drain compiler output so a successful verbose build cannot fail with SIGPIPE.
monkeyc -d "$DEVICE" -f monkey.jungle -o build/NycMta.prg -y "${DEVELOPER_KEY:-$HOME/.garmin/developer_key.der}" | sed -n '1,3p'

for p in $(pgrep -f MonkeyDoDeux); do
  if [ "$p" != "$$" ]; then kill -9 "$p" 2>/dev/null || true; fi
done
sleep 1
setsid nohup stdbuf -o0 -e0 monkeydo build/NycMta.prg "$DEVICE" > /tmp/app.log 2>&1 < /dev/null &
echo $! > /tmp/mta-app.pid

# Allow the app GPS/network watchdog to settle; inspect the screenshot for success.
# Configure the proxy through the local resource override or Garmin Connect.
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
