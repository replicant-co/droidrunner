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

Enable [Developer options → Wireless debugging](https://developer.android.com/tools/adb#connect-to-a-device-over-wi-fi) on the phone before running. **Use Android split-screen between Settings and Termux** while the script is running — Android dismisses the "Pair device with pairing code" popup (and the underlying pairing socket) when Settings is fully backgrounded, so the pair step will fail without it.

## License

Apache 2.0. See [`LICENSE`](./LICENSE).
