# Blocklog

Blocklog will be a personal iOS workout logger for PowerBlock adjustable dumbbells. For now it is an empty app that proves the build, test and install toolchain.

## Setup

Before using the recipes, complete these one-time steps:

1. Select Xcode as the active developer directory: `sudo xcode-select -s /Applications/Xcode.app`.
2. In Xcode, sign in with a free Apple account under **Settings → Accounts**.
3. Turn on Developer Mode on your iPhone and connect it to your Mac.
4. After the first `just device`, trust the developer under **Settings → General → VPN & Device Management**.

Install the pinned tools:

```sh
mise install
```

This installs XcodeGen 2.46.0, just 1.58.0, and xcbeautify 3.2.1. To activate mise in zsh, add `eval "$(mise activate zsh)"` to `~/.zshrc`; otherwise, prefix commands with `mise exec --`.

## Recipes

Run these commands from the repository root:

| Command | Action |
| --- | --- |
| `just generate` | Generate `Blocklog.xcodeproj` from `project.yml`. |
| `just build` | Build for the simulator. |
| `just test` | Run unit and UI tests. |
| `just test-unit` | Run unit tests. |
| `just test-ui` | Run UI tests. |
| `just test-one <identifier>` | Run one test by identifier. |
| `just run` | Build, install, and launch on the simulator; save `build/run.png`. |
| `just screenshot` | Capture screenshots in light, dark, and large accessibility text modes. |
| `just device` | Build, sign, install, and launch on a connected iPhone. |

Build and test logs go in `build/logs/`, and result bundles go in `build/results/`. Screenshot files are written to `build/screenshots/{light,dark,ax-large}/<screen>.png`. Set `SIM_NAME` to choose a simulator (default: **iPhone 17** on iOS 27), or set `DEVICE` to choose the phone for `just device`.

`Blocklog.xcodeproj` is generated and gitignored. Edit `project.yml`, not the generated project.

## Free-account signing

Free-account provisioning expires after 7 days and allows at most 3 sideloaded apps. Re-run `just device` weekly to reinstall and sign the app. The team ID `H2B8G7M3AZ` is committed in `project.yml`; it is not a secret.

## XcodeGen gate

With Xcode 27.0 (build 27A266a), XcodeGen 2.46.0 passed: project generation, builds, unit and UI tests, screenshots, and signed device installation work, so Tuist was not needed. The Xcode 27 install this was tested on has no `Simulator.app`, so the simulator runs headless and `just run` saves `build/run.png`. `devicectl list devices` also lists simulators, so `just device` filters for physical devices. It builds for the phone's own ID rather than `generic/platform=iOS` because a free team's provisioning profile needs the device registered, which happens with a device-specific build. Test recipes pass `-collect-test-diagnostics never` because a failing test otherwise starts a minutes-long `simctl diagnose`.

## License

MIT; see [LICENSE](LICENSE).
