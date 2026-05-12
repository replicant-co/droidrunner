#!/usr/bin/env bash
set -euo pipefail

# Minimal Android/Termux Hermes + Replicant MCP setup for same-phone control.
# Assumes Termux and Hermes are already installed, e.g. via install-hermes-termux.sh.
# Run in Termux: bash setup-replicant-adb.sh

say() { printf '\n==> %s\n' "$*"; }
warn() { printf '\n!! %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
run() { printf '+ %s\n' "$*"; "$@"; }
ask_yes() { printf '%s [y/N] ' "$1"; read -r a || true; case "$a" in y|Y|yes|YES) return 0;; *) return 1;; esac; }

say "Checking prerequisites"
have hermes || { warn "hermes not found. Install Hermes first, then rerun."; exit 1; }
have pkg || { warn "Termux pkg not found. This script is for Termux."; exit 1; }

say "Installing required Termux packages"
PKGS=()
have adb || PKGS+=(android-tools)
have node || PKGS+=(nodejs-lts)
have npm || PKGS+=(nodejs-lts)
have magick || PKGS+=(imagemagick)
[ "${#PKGS[@]}" -eq 0 ] || run pkg install -y "${PKGS[@]}"

for c in adb node npm magick; do have "$c" || { warn "missing required command: $c"; exit 1; }; done

say "Installing Replicant MCP"
# Required on Android/Termux: sharp's native postinstall/build commonly fails.
# Replicant is patched below to use an ImageMagick shim instead.
run npm install -g replicant-mcp --ignore-scripts

REPL_BIN="$(command -v replicant-mcp || true)"
[ -n "$REPL_BIN" ] || { warn "replicant-mcp not found after npm install"; exit 1; }
REPL_BIN_TARGET="$(readlink -f "$REPL_BIN" 2>/dev/null || printf '%s' "$REPL_BIN")"
[ -f "$REPL_BIN_TARGET" ] && chmod 755 "$REPL_BIN_TARGET"

say "Creating Android SDK-like ADB path"
mkdir -p "$HOME/android-sdk/platform-tools"
ln -sf "$(command -v adb)" "$HOME/android-sdk/platform-tools/adb"
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$HOME/android-sdk"

say "Patching Replicant for Termux/Android"
NPM_ROOT="$(npm root -g)"
DIST="$NPM_ROOT/replicant-mcp/dist"
[ -d "$DIST" ] || { warn "Replicant dist dir not found: $DIST"; exit 1; }
python - "$DIST" <<'PY'
from pathlib import Path
import re, sys
base = Path(sys.argv[1])
shim = base / "adapters" / "sharp-termux-shim.js"
shim.parent.mkdir(parents=True, exist_ok=True)

def backup(p):
    b = p.with_suffix(p.suffix + ".pre-termux-patch")
    if p.exists() and not b.exists(): b.write_bytes(p.read_bytes())

shim_src = r'''import { execFile } from "child_process";
import { promisify } from "util";
import { promises as fs } from "fs";
import * as os from "os";
import * as path from "path";
const execFileAsync = promisify(execFile);
class ImageMagickSharpShim {
  constructor(input) { this.input = input; this.resizeWidth = null; this.resizeHeight = null; this.resizeOpts = null; this.extractRegion = null; this.composites = []; this.outputFormat = null; this.quality = null; }
  async _withInputFile(fn) { if (Buffer.isBuffer(this.input)) { const f = path.join(os.tmpdir(), `replicant-sharp-input-${Date.now()}-${Math.random().toString(16).slice(2)}.png`); await fs.writeFile(f, this.input); try { return await fn(f); } finally { await fs.unlink(f).catch(() => {}); } } return await fn(this.input); }
  async metadata() { return await this._withInputFile(async f => { const { stdout } = await execFileAsync("magick", ["identify", "-format", "%w %h", f]); const [width, height] = stdout.trim().split(/\s+/).map(Number); return { width, height }; }); }
  sharpen() { return this; } withMetadata() { return this; }
  resize(width, height, options = {}) { this.resizeWidth = width; this.resizeHeight = height; this.resizeOpts = options; return this; }
  extract(region) { this.extractRegion = region; return this; }
  composite(items = []) { this.composites.push(...items); return this; }
  webp(options = {}) { this.outputFormat = "webp"; if (options.quality) this.quality = String(options.quality); return this; }
  jpeg(options = {}) { this.outputFormat = "jpeg"; if (options.quality) this.quality = String(options.quality); return this; }
  async _args(input, output) { const args = [input]; const temps = []; if (this.extractRegion) { const r = this.extractRegion; args.push("-crop", `${r.width}x${r.height}+${r.left}+${r.top}`, "+repage"); } for (const item of this.composites) { let over = item.input; if (Buffer.isBuffer(over)) { over = path.join(os.tmpdir(), `replicant-sharp-overlay-${Date.now()}-${Math.random().toString(16).slice(2)}.svg`); await fs.writeFile(over, item.input); temps.push(over); } args.push("(", over, ")", "-geometry", `+${item.left || 0}+${item.top || 0}`, "-composite"); } if (this.resizeWidth && this.resizeHeight) { let g = `${this.resizeWidth}x${this.resizeHeight}`; if (!this.resizeOpts || this.resizeOpts.fit !== "inside") g += "!"; if (this.resizeOpts?.withoutEnlargement) g += ">"; args.push("-resize", g); } if (this.quality) args.push("-quality", this.quality); args.push(output); return { args, temps }; }
  async toBuffer() { return await this._withInputFile(async input => { const { args, temps } = await this._args(input, `${this.outputFormat || "png"}:-`); try { return (await execFileAsync("magick", args, { encoding: "buffer", maxBuffer: 50 * 1024 * 1024 })).stdout; } finally { await Promise.all(temps.map(f => fs.unlink(f).catch(() => {}))); } }); }
  async toFile(output) { return await this._withInputFile(async input => { const { args, temps } = await this._args(input, output); try { await execFileAsync("magick", args, { maxBuffer: 50 * 1024 * 1024 }); return { path: output }; } finally { await Promise.all(temps.map(f => fs.unlink(f).catch(() => {}))); } }); }
}
export default function sharp(input) { return new ImageMagickSharpShim(input); }
'''
old_shim = shim.read_text() if shim.exists() else None
if old_shim != shim_src:
    backup(shim); shim.write_text(shim_src); print("wrote", shim)

for p in sorted(set(base.rglob("environment.js")) | set(base.rglob("*environment*.js"))):
    try: s = p.read_text()
    except UnicodeDecodeError: continue
    s2 = s.replace('platform === "linux"', 'platform === "linux" || platform === "android"').replace("platform === 'linux'", "platform === 'linux' || platform === 'android'")
    if s2 != s:
        backup(p); p.write_text(s2); print("patched android platform in", p)

sharp_import = re.compile(r'''import\s+sharp\s+from\s+['"]sharp['"]\s*;''')
for p in sorted(base.rglob("*.js")):
    if p == shim: continue
    try: s = p.read_text()
    except UnicodeDecodeError: continue
    if "sharp-termux-shim.js" in s or not sharp_import.search(s): continue
    rel = "./sharp-termux-shim.js" if p.parent == shim.parent else "../adapters/sharp-termux-shim.js"
    backup(p); p.write_text(sharp_import.sub(f'import sharp from "{rel}";', s)); print("patched sharp import in", p)
PY

say "Adding Replicant MCP to Hermes"
if hermes mcp list 2>/dev/null | grep -qE '(^|[[:space:]])replicant([[:space:]]|$)'; then
  warn "Hermes MCP server 'replicant' already exists; leaving it in place."
else
  printf 'Y\n' | hermes mcp add replicant --command replicant-mcp --env ANDROID_HOME="$ANDROID_HOME" ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
fi
hermes mcp test replicant || warn "MCP test failed. Rerun after fixing the error above."

say "Pair same-phone Wireless debugging"
printf '%s\n' "IMPORTANT: use Android split screen. Keep Settings/Wireless debugging visible while Termux runs this script."
printf '%s\n' "In Settings -> Developer options -> Wireless debugging, enable it and tap 'Pair device with pairing code'."
printf 'Pairing port from popup, blank to skip: '
read -r PAIR_PORT || PAIR_PORT=""
if [ -n "$PAIR_PORT" ]; then
  printf 'Pairing code from popup: '
  read -r PAIR_CODE || PAIR_CODE=""
  [ -n "$PAIR_CODE" ] && adb pair "127.0.0.1:$PAIR_PORT" "$PAIR_CODE"
fi

printf 'Connect port from main Wireless debugging "IP address & port" line, blank to skip: '
read -r CONNECT_PORT || CONNECT_PORT=""
if [ -n "$CONNECT_PORT" ]; then
  adb connect "127.0.0.1:$CONNECT_PORT"
  adb devices -l
  if ask_yes "Switch to persistent local ADB transport at 127.0.0.1:5555?"; then
    adb -s "127.0.0.1:$CONNECT_PORT" tcpip 5555
    sleep 2
    adb connect 127.0.0.1:5555 || { sleep 2; adb connect 127.0.0.1:5555 || true; }
    adb devices -l
  fi
fi

say "Done"
printf '%s\n' "Restart/resume Hermes if Replicant tools are not visible in the current session."
printf '%s\n' "Prefer the online 127.0.0.1:5555 device; stale offline connect-port entries can be ignored."
