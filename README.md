# droidrunner

Friction-free installer for [Hermes Agent](https://github.com/NousResearch/hermes-agent) on Android (Termux, aarch64).

## Install

Inside [Termux](https://termux.dev/) (install the [F-Droid](https://f-droid.org/packages/com.termux/) build, not Play Store; disable Google Play Protect before installing Termux if you haven't already):

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

Enable [Developer options → Wireless debugging](https://developer.android.com/tools/adb#connect-to-a-device-over-wi-fi) on the phone before running. For the pairing step, also install [Termux:Float](https://f-droid.org/packages/com.termux.window/) from F-Droid (same signing key as Termux) and grant it "Display over other apps" under Android Settings → Apps → Special app access → Display over other apps → Termux:Float. Its floating terminal hovers over Settings, so the "Pair device with pairing code" popup (and the underlying pairing socket) stays alive while you type — Android dismisses both when Settings is fully backgrounded.

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
