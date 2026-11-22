#!/usr/bin/env bash
set -euo pipefail

upstream="$1"
output="$2"
mkdir -p "$output"
test "$(git -C "$upstream" rev-parse HEAD)" = 9c20ef321f311a3dd3f051ebd820abbc8f952413
fixture="$upstream/scripts/webdav-fixture.py"
port=8181
root="$output/fixtures"

# Supply original audio and lyrics to the upstream HTTP server.
python3 - "$root" <<'PY'
import math
import struct
import sys
import wave
from pathlib import Path

root = Path(sys.argv[1])
album = root / "Music" / "Signal Choir" / "Night Transmission"
album.mkdir(parents=True, exist_ok=True)
for folder, name, frequency in (
    (album, "Signal Archive", 220),
    (album, "Quiet Vector", 262),
    (root / "Music", "Foreign - Jóga", 330),
):
    with wave.open(str(folder / f"{name}.wav"), "wb") as audio:
        rate = 8_000
        audio.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        frames = (
            struct.pack("<h", int(4096 * math.sin(2 * math.pi * frequency * index / rate)))
            for index in range(rate * 50)
        )
        audio.writeframes(b"".join(frames))
(album / "Signal Archive.lrc").write_text(
    "[00:02]<00:02>Signals <00:04>arrive<00:06>\n"
    "[00:18]<00:18>Follow <00:21>the <00:22>signal<00:28>\n",
    encoding="utf-8",
)
PY

# Run the pinned protocol fixture on loopback. Consume PROPFIND request bodies
# before delegating so it can serve another request on the same connection.
WEBDAV_REQUEST_LOG="$output/requests.log" python3 - "$fixture" "$port" "$root" > "$output/server.log" 2>&1 <<'PY' &
import http.server
import os
import runpy
import sys
import threading

sys.argv.pop(0)
fixture = runpy.run_path(sys.argv[0])
drop_lock = threading.Lock()

class Handler(fixture["Handler"]):
    drop_once = os.environ.get("STRSK_WEBDAV_DROP_ONCE") == "1"

    def do_PROPFIND(self):
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
        with drop_lock:
            drop = type(self).drop_once and self.path.endswith("/Signal%20Choir/")
            if drop:
                type(self).drop_once = False
        if drop:
            self.record("connection-dropped")
            self.close_connection = True
            return
        super().do_PROPFIND()

http.server.ThreadingHTTPServer(("127.0.0.1", fixture["PORT"]), Handler).serve_forever()
PY
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 40); do
    if curl --noproxy '*' --silent --fail --max-time 1 \
        --user listener:correct-horse -X PROPFIND -H 'Depth: 1' "http://localhost:$port/Music/" >/dev/null; then
        printf '%s\n' "$pid" > "$output/server.pid"
        trap - EXIT
        exit 0
    fi
    sleep 0.25
done
cat "$output/server.log" >&2
exit 1
