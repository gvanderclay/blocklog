# Blocklog

Blocklog is a personal iOS workout logger for PowerBlock adjustable dumbbells. It logs workouts with weights chosen from the PowerBlock settings, adds exercises from a picker (including custom exercises), shows the previous numbers for each set, and exports and restores a JSON backup.

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
| `just test` | Run the unit tests (same as `just test-unit`). |
| `just test-unit` | Run unit tests. |
| `just test-one <identifier>` | Run one test by identifier. |
| `just ci-report <run-id>` | Download a failed CI run's artifacts and print its test failures, recovered retries and crash reports. |
| `just run` | Build, install, and launch on the simulator; save `build/run.png`. |
| `just device` | Build, sign, install, and launch on a connected iPhone. |
| `just fmt` | Format the Swift sources with the toolchain's `swift format`. |
| `just skills` | Export Apple's SwiftUI agent skills into `.agents/skills/apple/`. |
| `just chime` | Regenerate the rest-end chime, `App/Resources/rest-chime.caf`. |
| `just icon` | Regenerate the light, dark and tinted app icons. |

Build and test logs go in `build/logs/`, and result bundles go in `build/results/`. Set `SIM_NAME` to choose a simulator (default: **iPhone 17** on iOS 27), or set `DEVICE` to choose the phone for `just device`.

`Blocklog.xcodeproj` is generated and gitignored. Edit `project.yml`, not the generated project.

## Free-account signing

Free-account provisioning expires after 7 days and allows at most 3 sideloaded apps. Re-run `just device` weekly to reinstall and sign the app. The team ID `H2B8G7M3AZ` is committed in `project.yml`; it is not a secret.

## XcodeGen gate

With Xcode 27.0 (build 27A266a), XcodeGen 2.46.0 passed: project generation, builds, unit tests, and signed device installation work, so Tuist was not needed. The Xcode 27 install this was tested on has no `Simulator.app`, so the simulator runs headless and `just run` saves `build/run.png`. `devicectl list devices` also lists simulators, so `just device` filters for physical devices. It builds for the phone's own ID rather than `generic/platform=iOS` because a free team's provisioning profile needs the device registered, which happens with a device-specific build. Test recipes pass `-collect-test-diagnostics never` because a failing test otherwise starts a minutes-long `simctl diagnose`.

## CI

`.github/workflows/ci.yml` runs `just ci-test BlocklogUnit` as the `unit` job on the `xcode-27` runner for every push to `main` and every pull request that changes more than `docs/**` or `*.md` files. On a pull request that filter applies to the whole pull request diff, so a docs-only commit on a pull request that also changes code still runs CI. The same recipes run locally. The first green run used Xcode 27.0 and Apple Swift 6.4 on image `macos27` 20260928.0222.1 (`unit` job). Unit tests hosted in the app ran with signing disabled (`hostedInApp()` passed). The `unit` job took 3m06s. After the test step, a separate "Report CI failure" step runs `scripts/ci-report.py` (3-minute limit). It prints a diagnosis, the `ci-test` phase lines, the failing tests, crash reports and the log tail, writes the same as Markdown to the job's step summary, and adds `::error` annotations (with file and line when the result bundle has them) for failures and `::warning` annotations for a test that failed and then passed on a retry. It exits 1 only when the test step failed, so `gh run view --log-failed` shows it; a missing result bundle or zero tests ran is reported as an infrastructure failure. A failed, cancelled or timed-out job, or one with a recovered retry, then collects the simulator's system log and crash reports (4-minute limit) and uploads `build/logs/` and `build/results/` for 7 days; the test step's own 16-minute limit leaves time for that inside the job's 36 minutes. `/usr/bin/python3 scripts/test_ci_report.py` checks the reporter.

`mise.toml` pins [simslim](https://github.com/MobAI-App/simslim) 0.11.0, so the job installs it with the rest of the tools. `ci-test` slims the simulator (every category disabled) in the background while `build-for-testing` compiles, logging the time and `simslim measure`; if that fails the job fails rather than testing on a stock simulator. Locally it skips the slim when `simslim status` already reports the simulator slim, and boots the stock simulator if simslim is missing. It also turns on Xcode's compilation cache outside DerivedData; the job restores it with `actions/cache/restore`, and only pushes to `main` save it. The test step's limit stays 16 minutes, and the job's 36 minutes are 4 setup, 3 cache restore, 16 build and test, 3 report, 4 log collection, 3 cache save and 3 upload.

A CI simulator boots for the first time in every run, and for its first ten minutes or so it is too busy for tests: the test runner can take minutes to start and be killed before any test runs, and taps can take a minute each. `ci-test` therefore builds once, then runs `test-without-building`, and if the test runner never started it reruns the tests once and marks the job with a warning; `-retry-tests-on-failure` covers a test that fails while the simulator is still busy. It sets `NSUnbufferedIO=YES` so that xcbeautify streams its output instead of holding it until exit, and passes `-collect-test-diagnostics never` so that a failure does not add a 600-second `simctl diagnose`. `docs/research/ci-ui-test-stall.md` has the sources.

## License

MIT; see [LICENSE](LICENSE).
