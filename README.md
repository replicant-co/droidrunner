# droidrunner

Friction-free installer for [Hermes Agent](https://github.com/NousResearch/hermes-agent) on Android (Termux, aarch64).

## Termux

Two Termux apps, both from [F-Droid](https://f-droid.org/) (not Play Store — they need to share the same signing key). Disable Google Play Protect first; modern Android blocks Termux install otherwise.

- [Termux](https://f-droid.org/packages/com.termux/) — the terminal that runs Hermes.
- [Termux:Float](https://f-droid.org/packages/com.termux.window/) — a floating terminal that hovers over other apps. Used for the Wireless debugging pair step in [Wire Replicant MCP](#wire-replicant-mcp) below.

Termux:Float needs the "Display over other apps" permission. On Android 13+ that toggle is greyed out for sideloaded apps until you first unlock **restricted settings** — see Google's [Allow restricted settings](https://support.google.com/android/answer/12623953?p=restricted_settings) explainer. The full sequence:

1. Open Termux:Float once from the launcher so Android registers it. Android won't list it under "Display over other apps" until then.
2. **Unlock restricted settings.** Settings → Apps → All apps → **Termux:Float** → tap the **⋮** menu (top right of the app info page) → **Allow restricted settings** → confirm the warning. Without this, the toggle in step 3 stays greyed out.
3. **Grant the permission.** Still on Termux:Float's app info page → **Permissions** → **Display over other apps** → toggle **Allow display over other apps** on. (Same toggle is reachable from Settings → Apps → Special app access → Display over other apps → Termux:Float.)
4. **Force stop** Termux:Float on the same app info page, then reopen it from the launcher. It only actually floats after the permission is live and the process restarts.

Troubleshooting:

- "Display over other apps" stays greyed out → you skipped step 2.
- Termux:Float opens full-screen instead of floating → the permission isn't applied to the running process yet, repeat step 4.

## Install

In Termux:

```sh
curl -fsSL -O https://raw.githubusercontent.com/replicant-co/droidrunner/main/installer/install-hermes-termux.sh
bash install-hermes-termux.sh --skip-setup
```

About 30 minutes cold. When it finishes, `hermes` is on your `$PATH`. Run `hermes setup` when you're ready to configure API keys.

## Wire Replicant MCP

Hermes on a phone needs to drive the phone to be useful. After the installer above finishes, run this in Termux to wire up [Replicant MCP](https://www.npmjs.com/package/replicant-mcp) so Hermes can control the same device it's running on, over local ADB:

```sh
curl -fsSL -O https://raw.githubusercontent.com/replicant-co/droidrunner/main/installer/setup-replicant-adb.sh
bash setup-replicant-adb.sh
```

The script installs `replicant-mcp` (with `--ignore-scripts` — sharp's native build fails on Android/arm64 and Replicant gets patched to use an ImageMagick shim instead), patches Replicant's dist for Termux, registers a `replicant` MCP server with Hermes, then walks you through Android's Wireless debugging pairing on the same phone and ends on a persistent `127.0.0.1:5555` ADB transport. Restart `hermes chat` after it finishes so the new MCP tools load.

Enable [Developer options → Wireless debugging](https://developer.android.com/tools/adb#connect-to-a-device-over-wi-fi) on the phone before running. Android dismisses the "Pair device with pairing code" popup (and the underlying pairing socket) when Settings is fully backgrounded, so the pair step needs [Termux:Float](#termux) — its floating terminal hovers over Settings without backgrounding it.

Run the install / patches / MCP-registration portion of `setup-replicant-adb.sh` in regular Termux. When the script reaches the pair prompts, press Enter at both to skip them, then open Settings → Wireless debugging → "Pair device with pairing code" and finish from a Termux:Float window:

```sh
adb pair "127.0.0.1:<PAIRING_PORT>" "<PAIRING_CODE>"
adb connect "127.0.0.1:<CONNECT_PORT>"
adb -s "127.0.0.1:<CONNECT_PORT>" tcpip 5555
adb connect 127.0.0.1:5555
```

`PAIRING_PORT` and `PAIRING_CODE` come from the popup; `CONNECT_PORT` is the port shown at "IP address & port" on the main Wireless debugging screen.

## License

Apache 2.0. See [`LICENSE`](./LICENSE).
