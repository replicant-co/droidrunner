# droidrunner

Friction-free installer for [Hermes Agent](https://github.com/NousResearch/hermes-agent) on Android (Termux, aarch64).

## Termux

Two Termux apps, both from [F-Droid](https://f-droid.org/). They need to share a signing key, which the Play Store can't provide. Turn off Google Play Protect first, or modern Android will refuse the install.

- [Termux](https://f-droid.org/packages/com.termux/) — the terminal that runs Hermes.
- [Termux:Float](https://f-droid.org/packages/com.termux.window/) — a floating terminal that hovers over other apps. Used for the Wireless debugging pair step in [Wire Replicant MCP](#wire-replicant-mcp) below.

Termux:Float needs the "Display over other apps" permission. On Android 13+ that toggle is greyed out for sideloaded apps until you unlock **restricted settings** first. (Google's [Allow restricted settings](https://support.google.com/android/answer/12623953?p=restricted_settings) page covers why.) Full sequence:

1. Open Termux:Float once from the launcher so Android registers it. Android won't list it under "Display over other apps" until then.
2. **Unlock restricted settings.** Settings → Apps → All apps → **Termux:Float** → tap the **⋮** menu (top right of the app info page) → **Allow restricted settings** → confirm the warning. Without this, the toggle in step 3 stays greyed out.
3. **Grant the permission.** Still on Termux:Float's app info page → **Permissions** → **Display over other apps** → toggle **Allow display over other apps** on. (Same toggle is reachable from Settings → Apps → Special app access → Display over other apps → Termux:Float.)
4. **Force stop** Termux:Float on the same app info page, then reopen it from the launcher. It only actually floats after the permission is live and the process restarts.

Troubleshooting:

- "Display over other apps" stays greyed out → you skipped step 2.
- Termux:Float opens full-screen instead of floating → the permission isn't live in the running process; force-stop and reopen (step 4).

## Install

In Termux:

```sh
curl -fsSL -O https://raw.githubusercontent.com/replicant-co/droidrunner/main/installer/install-hermes-termux.sh
bash install-hermes-termux.sh --skip-setup
```

About 30 minutes cold. When it finishes, `hermes` is on your `$PATH`. Run `hermes setup` when you're ready to configure API keys.

## Wire Replicant MCP

Hermes on a phone needs to drive the phone to be useful. Wiring up [Replicant MCP](https://www.npmjs.com/package/replicant-mcp) lets Hermes control the same device it's running on, over local ADB.

Enable [Developer options → Wireless debugging](https://developer.android.com/tools/adb#connect-to-a-device-over-wi-fi) on the phone first, then in regular Termux:

```sh
curl -fsSL -O https://raw.githubusercontent.com/replicant-co/droidrunner/main/installer/setup-replicant-adb.sh
bash setup-replicant-adb.sh
```

The script installs `replicant-mcp` with `--ignore-scripts` (sharp's native build fails on Android/arm64; Replicant is patched to use an ImageMagick shim instead), patches Replicant's dist for Termux, and registers a `replicant` MCP server with Hermes. Then it walks you through Wireless debugging pairing on the same phone and drops you onto a persistent `127.0.0.1:5555` ADB transport.

Android dismisses the "Pair device with pairing code" popup (and the underlying pairing socket) when Settings is fully backgrounded. That's why the pair step needs [Termux:Float](#termux): its floating terminal hovers over Settings without sending it to the background. When the script reaches the pair prompts, press Enter at both to skip them, then open Settings → Wireless debugging → "Pair device with pairing code" and finish from a Termux:Float window:

```sh
adb pair "127.0.0.1:<PAIRING_PORT>" "<PAIRING_CODE>"
adb connect "127.0.0.1:<CONNECT_PORT>"
adb -s "127.0.0.1:<CONNECT_PORT>" tcpip 5555
adb connect 127.0.0.1:5555
```

`PAIRING_PORT` and `PAIRING_CODE` come from the popup; `CONNECT_PORT` is the port shown at "IP address & port" on the main Wireless debugging screen. Restart `hermes chat` after the script finishes so the new MCP tools load.

## Keep it running

Two things to know before you leave it running.

- **Wi-Fi changes don't break ADB.** `adb connect 127.0.0.1:5555` rides over localhost, so going off Wi-Fi or switching networks won't touch it. The link stays alive as long as the phone is on. Reboots break it, though: `tcpip` mode resets to USB. Re-pair through Wireless debugging after every restart.
- **Android will kill Termux.** Android reaps background processes aggressively, and when Termux dies, `hermes chat` and any running agent die with it. Long-press the Termux notification → **Acquire Wakelock**, then exempt Termux from battery optimisation at Settings → Apps → Termux → Battery → **Unrestricted**.

## License

Apache 2.0. See [`LICENSE`](./LICENSE).
