# Why do XCUITest jobs stall before the first test on GitHub Actions, and what fixes are documented?

## Short answer

Treat this as **three separate problems**, not one: simulator/test-runner preparation can fail before tests start; failure diagnostics can then add a ten-minute delay; and buffered output can conceal which phase is stuck. The strongest immediate changes for Blocklog are (1) pass `-collect-test-diagnostics never` to the **CI** test invocation, (2) export `NSUnbufferedIO=YES` for both xcodebuild and xcbeautify, or stream raw output with `tee` and format afterward, and (3) make simulator boot an observable, bounded step, with one fresh-device retry only for a verified preparation failure. These are ranked recommendations, not a proven diagnosis of the original runner crash. [L1][L2][B1][B2][R2][C1]

**Important local finding:** at commit `c451ddf25225fc55dff307f1125573ea27a8cc78`, local test recipes already use `no_diag := "-collect-test-diagnostics never"`, but `ci-test` does **not** pass it. `ci-test` already passes `-parallel-testing-enabled NO`; adding that flag again cannot explain or fix the reported run. Its `bootstatus` stdout is redirected to `/dev/null`, so a boot hang can itself produce silence before xcodebuild is reached. [L1]

## Date, versions and scope

Checked **2026-10-07**. Local `xcodebuild -version` reports **Xcode 27.0, build 27A266a**; `mise exec -- xcbeautify --version` reports **3.2.1**. Repo baseline is `c451ddf25225fc55dff307f1125573ea27a8cc78`. `justfile` and `.github/workflows/ci.yml` were already being modified by the parent session; this report cites the committed baseline rather than attributing concurrent edits to the original failure. No app or CI code was changed here. [L1][L2]

Current primary documentation checked: installed Apple CLI help/man page, Xcode 27 release notes, GitHub's Xcode 27 preview announcement (edited September 16, updated October 6), xcbeautify source pinned to `513e4b12c3f6c965d1d3b66bd5cd9d635f03112d`, fastlane source pinned to `3d31dd995c222356bec72dcb5be515a4d1776ef1`, and Mendoza source documentation pinned to `0d562601110bab102fcb2ad897eeb0aea4155e48` (October 6). Historical issue reports and the CircleCI practitioner article are explicitly labelled older below. [A1][R1][B1][F1][M1]

The supplied symptoms (0 tests passed, preparation crash, `XCTWaiter handleStalledWait`, 600-second diagnostics timeout, subsequent 20-minute cancellation, and local passing tests followed by diagnostics) are **task-provided observations**, not independently reproduced CI findings. The buffering behavior was independently reproduced locally; no hosted CI test or simulator-reset experiment was run. [L3]

## 1. What causes the pre-test stall, and what workarounds have evidence?

### Cold boot / simulator services not ready

CircleCI's Constantin Jacob describes simulator boot exceeding xcodebuild's preparation deadlines under CI resource contention and recommends starting the simulator early, while dependencies or compilation run. This is a **first-person CI-vendor experience report**, updated October 31, 2025 (**older**), not an Apple specification of current Xcode internals. [C1]

Apple's installed `simctl help bootstatus` confirms that `bootstatus <device> -b` boots an unbooted device and monitors it until boot finishes; unlike `simctl boot`, it is a readiness wait, not just a boot request. Its help lists no timeout option. Put this in a separately timed CI step, retain its output, and select the same UDID in `-destination`. A bounded boot wait is a recommendation, not a claim that boot completion guarantees XCTest/Accessibility readiness. [L2][C1]

Preboot is **not sufficient for every image regression**. A Bitwarden contributor reported that `bootstatus` itself hung without output, then found `bootstatus -b` stuck at “Waiting on BackBoard”; this matches the possibility that Blocklog's later cancellation happened inside the newly added boot step, not the formatter. That report concerns Xcode/iOS 26 in October 2025 (**older**), not verified Xcode 27 behavior. [R2]

### Runtime, VM and runner-image regressions

GitHub runner-image maintainers acknowledged Xcode 26.x/CoreSimulator performance degradation and fragility in virtual environments, affecting even older selected Xcodes when the shared CoreSimulator installation changed. Their November 2025 response recommends waiting for updated toolchains and identifies then-stable Xcode 16.3+ on macOS 15; this is **older evidence of the failure class**, not a recommendation to build this iOS 27 app with Xcode 16. [R3]

In an earlier Xcode 15.3/iOS 17 regression, users reported launchd boot failures, Accessibility initialization timeouts and major increases in time to first test, despite local success. GitHub's maintainer recommended larger macOS runners; user reports of image fixes were mixed, and one report explicitly retracted an apparent fix after the next run failed. These are **older 2024 reports**, so neither “a rerun passed” nor “preboot completed” establishes the root cause. [R4][R5][R6]

For the actual generation in use, GitHub marks `xcode-27` as **preview**, warns that software may be unstable, and states that its base OS switched to macOS 27 on September 16, 2026. Record the image version, Xcode build and simulator runtime build from the failing job, then compare a supported newer image/toolchain or a larger/self-hosted runner. **Unknown:** no inspected source establishes an Xcode 27 image defect specifically responsible for Blocklog's `handleStalledWait`. Do not recommend downgrading below this app's iOS 27 requirements without a separate compatibility decision. [R1][R3][R5]

Apple's Xcode 27 notes say simulator runtimes now contain a pre-built dyld cache to speed first launch. They also document a console issue where stdout/stderr streaming from multiple processes can be significantly delayed (165098287). Neither entry identifies `handleStalledWait` as a known Xcode 27 startup bug. [A1]

### Parallel simulator clones and resource pressure

Apple documents `-parallel-testing-enabled YES|NO` as overriding the scheme's per-target parallel-testing setting; reducing clone/concurrent simulator work is a sensible isolation step on small CI hosts. Historical runner issues contain failures preparing cloned simulators and booting launchd. **Unknown:** no inspected Apple source says disabling parallel testing universally fixes runner preparation crashes. In this repo it is **already disabled**, so this is a checked precaution, not a new top-three fix. [L1][L2][R4]

### Persistent simulator state / poisoned test session

The fastlane issue tracker has first-person reports that resetting simulators, rebooting the VM or rerunning the job helped intermittent bootstrap failures; one contributor ultimately attributed their failures to boot taking too long and reported success with simulator cleanup/reset. Another reports only partial improvement from splitting `build-for-testing` and `test-without-building`, and later commenters say the split did not help. These are **older 2018–2019 observations**, not guaranteed remedies. [F2][F3]

A fresh CI-only device or shutdown-and-erase of the selected disposable device is therefore a reasonable **controlled experiment** after a preparation failure, not an unconditional fix. Erasing removes state and can reintroduce first-boot and keyboard onboarding work. Never erase the user's local simulator indiscriminately. Check `xcrun simctl help erase` on the installed toolchain before applying this experiment; no erase was executed in this research. [F2][F3][F4]

The documented `-retry-tests-on-failure -test-iterations 2` means a maximum of two iterations for failing tests. It is **not documented as a simulator recreation or boot-recovery policy**. Do not infer from those flags that a runner that never established a test session will be recreated successfully. A bounded outer retry should be limited to a verified infrastructure/preparation failure and preserve the first log/result bundle; it must not turn ordinary assertion failures green by ignoring them. [L2]

### Hardware keyboard and keyboard onboarding

There is concrete fastlane evidence for:

```sh
# Host Simulator preference, not an app build setting.
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
```

A fastlane issue reporter says that adding this setting fixed missing software-keyboard behavior in their CI script; the underlying merged work modifies per-device preferences as well. This is an **older 2019 keyboard visibility workaround**, not evidence that the setting fixes a crash before any test starts. [F5]

For the iOS 13 “Slide to Type” tutorial, fastlane implements `disable_slide_to_type` by adding `KeyboardContinuousPathEnabled = false` to the selected simulator's `data/Library/Preferences/com.apple.keyboard.ContinuousPath.plist`. Its source is a stronger basis than inventing a `defaults write` domain or a `KeyboardDidShowContinuousPathIntroduction` key. [F1][F4]

Stack Overflow answers identify the tutorial view as `UIContinuousPathIntroductionView` or tap its Continue button. These are **secondary, older 2019–2021 reports**, checked through Stack Exchange's API, for problems *after focusing a text field*. They do not explain a preparation crash before the first test. **Unknown:** the cited preference's effectiveness on an iOS 27 CI simulator; validate before adding it. [S1]

### What `XCTWaiter handleStalledWait` actually establishes

**Unknown:** no inspected Apple documentation or exact-match issue established a unique root cause for this symbol. It is a stack frame accompanying a stalled waiter, not enough evidence to choose keyboard, main-thread deadlock, missing framework, VM resource starvation or simulator initialization as the cause. The next useful evidence is the complete runner crash report and test-session/host/Accessibility logs, not a broad set of speculative preference changes. The exact-symbol web search found an unrelated Firebase deadlock report, which is not a basis for assigning Blocklog a Firebase problem. [Q1]

Apple Developer Forums search located thread **805060**, “Unable to launch tests in Xcode 26,” with a search snippet reporting a 300-second runner connection hang and thread **691809**, “Test runner never began executing tests after launching.” Their page bodies were blocked by Apple's automated-access verification, so **their replies, Apple staff attribution, and remedies are unknown and are not used as evidence for fixes**. [Q2]

## 2. What triggers the post-test diagnostics delay, and how can it be disabled?

The exact supported flag in this installed Xcode is:

```sh
-collect-test-diagnostics never
# Alternative supported value:
-collect-test-diagnostics on-failure
```

This is **not** `NO`, `false`, `off`, or an invented `-disable-test-diagnostics` flag. Installed `xcodebuild -help` says it controls verbose diagnostics such as sysdiagnose when encountering failure. Installed `man xcodebuild` calls these diagnostics “verbose and long-running,” includes sysdiagnoses/log archives, and says omitting the flag uses the value in the test plan. Both were checked on **27.0 / 27A266a**. [L2]

Mendoza's author/maintainer documentation now explicitly disables collection by default: it describes xcodebuild running `simctl diagnose` with a **600-second timeout after a failure verdict**, including retried failures, and adding hundreds of megabytes to results. This is a **current primary implementation/experience report by the UI-test orchestration tool's author**, not Apple documentation of every internal timeout. It says crash reports are still collected; the Apple man page does not independently enumerate that retention guarantee. [M1]

This explains why disabling collection is highly likely to remove the supplied ten-minute **tail**, but it does not make a preparation crash pass. Likewise, an ultimately passing suite can contain an earlier failed/retried attempt that triggered collection. **Unknown:** whether that is what happened in Blocklog's local passing run; no original result bundle was examined here, and a genuinely failure-free run triggering verbose diagnostics would need separate investigation. [L2][M1]

**No documented diagnostics-timeout override was found** in the installed `xcodebuild -help` or `man xcodebuild`. `-destination-timeout` only limits destination lookup; `-test-timeouts-enabled`, `-default-test-execution-time-allowance`, and `-maximum-test-execution-time-allowance` govern test execution, not the sysdiagnose tail. Use `never` to opt out, or retain `on-failure` and bound the entire CI step/job, accepting loss of unfinished artifacts if it is forcibly cancelled. Do not claim that setting a test execution allowance limits preparation or diagnostic collection. [L2]

## 3. Why do piped logs appear at the end, and how can they stream?

There are **two possible buffering boundaries**. xcbeautify's README recommends unbuffered xcodebuild stdout and redirecting stderr to stdout; its source also reads incrementally with `readLine()` and writes using Swift `print`. It does not intentionally collect the whole input before formatting, and the checked CLI exposes **no unbuffered/flush flag**. `--renderer github-actions` changes rendering/annotations; `--is-ci` prints test results under quiet modes; neither promises to flush stdout. `--preserve-unbeautified` prevents filtering of otherwise unrecognized lines, not buffering. [B1][B2][L2]

**Local reproduction on xcbeautify 3.2.1:** a Python subprocess wrote `PROBE first\n`, flushed stdin, and checked piped stdout for one second **before closing stdin**. Without the environment variable there was no readable output; with `NSUnbufferedIO=YES` on the formatter there was immediate readable output. In both cases output appeared after EOF. This confirms formatter stdout buffering in this local non-terminal pipe, independently of xcodebuild; it does not prove the GitHub web UI itself buffers every job until completion. [L3]

Recommended pipeline (illustrative, not applied):

```sh
set -o pipefail
export NSUnbufferedIO=YES
xcodebuild test ... -collect-test-diagnostics never 2>&1 \
  | tee build/logs/BlocklogUI.log \
  | xcbeautify --renderer github-actions --preserve-unbeautified
```

**Export** the variable, or put it in the step's environment, so both executable processes receive it. `NSUnbufferedIO=YES xcodebuild ... | xcbeautify` applies it only to the producer; that README example helps xcodebuild buffering but does not ensure the formatter's piped stdout is unbuffered. `tee` preserves raw input as it arrives but cannot recover bytes the producer has not flushed; `pipefail` preserves pipeline failure status, not streaming. [B1][B2][L3]

For incident diagnosis the simplest alternative is raw `xcodebuild ... 2>&1 | tee "$log"` in the live step, followed by formatting the saved log after the command finishes. Add timestamped phase messages around boot/build/test, and keep bootstatus output rather than redirecting it away. This is an observability recommendation, not a guarantee that Xcode 27's documented multiprocess-console delay is eliminated. Apple acknowledges significantly delayed stdout/stderr in multiprocess scenarios. [A1][L1][L3]

## Ranked conclusion for Blocklog

1. **Disable long-running diagnostics on the CI test invocation.** This is the clearest verified omission in the committed recipe and targets the exact 600-second tail: Apple CLI verifies `-collect-test-diagnostics never`; Mendoza documents the matching delay. It does **not** repair the underlying pre-test crash. [L1][L2][M1]
2. **Export `NSUnbufferedIO=YES` to both pipeline endpoints, or show raw tee output live.** The formatter's own buffering was reproduced locally, its upstream README supports unbuffered producer output, and Apple documents additional Xcode 27 console delays. This restores evidence rather than curing simulator startup. [B1][L3][A1]
3. **Keep preboot, but make it visible and separately bounded; if a preparation failure persists, try one fresh-device rerun or a newer/larger supported runner.** Historical CI reports document boot/preparation hangs and even bootstatus hanging; GitHub's actual Xcode 27 image is still preview. Serial execution is already enabled, so prefer an image/device experiment over adding duplicate flags or speculative keyboard settings. The exact best runner/reset remedy remains **unverified for Xcode 27 and Blocklog**. [C1][R2][R1][R5][L1]

## Evidence index

- **[L1] Repo baseline:** `git rev-parse HEAD` → `c451ddf25225fc55dff307f1125573ea27a8cc78`; `git show HEAD:justfile | nl -ba`: lines **9–10** define `no_diag`, **58–68** use it locally, **74–87** implement CI boot and the test invocation, **77** discards boot stdout, **85** disables parallel testing, **86–87** omit diagnostics suppression and pipe to xcbeautify. `git status --short` initially reported modified `justfile` and `.github/workflows/ci.yml`. These command outputs were checked October 7, 2026.
- **[L2] Installed Apple/tool CLI, October 7, 2026:** `xcodebuild -version` → `Xcode 27.0 / Build version 27A266a`; `xcodebuild -help` → `-collect-test-diagnostics on-failure|never ... verbose diagnostics (like a sysdiagnose) when encountering a failure`; `man xcodebuild | col -b`, extracted lines **433–436** → `-collect-test-diagnostics [on-failure | never] ... verbose and long-running diagnostics ... If not specified, the value in the test plan will be used.` Man lines **103–105**, **377–379**, **397–431** document destination timeout, parallelization, test timeout/repetition behavior. `xcrun simctl help bootstatus` → `Usage: simctl bootstatus <device> [-bcd]`, `-b Boot the device if it isn't already booted`, monitors until boot completes. `mise exec -- xcbeautify --version` → `3.2.1`; `--help` has the flags discussed above and no flush/unbuffered option. A readable **secondary mirror**, not the authority for this check: https://keith.github.io/xcode-man-pages/xcodebuild.1.html .
- **[L3] Runnable buffering probe / output:** the following was run locally October 7, 2026 (no build or simulator mutation):

  ```python
  import os, select, subprocess
  binary = '/Users/gvanderclay/.local/share/mise/installs/xcbeautify/3.2.1/xcbeautify'
  for unbuffered in (False, True):
      env = dict(os.environ)
      env.pop('NSUnbufferedIO', None)
      if unbuffered:
          env['NSUnbufferedIO'] = 'YES'
      p = subprocess.Popen(
          [binary, '--preserve-unbeautified', '--disable-logging', '--disable-colored-output'],
          stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
      p.stdin.write('PROBE first\n')
      p.stdin.flush()
      print(unbuffered, bool(select.select([p.stdout], [], [], 1)[0]))
      p.stdin.close()
      p.wait(timeout=5)
      print(repr(p.stdout.read()))
  ```

  Observed output: `False False`, `'PROBE first\n'`, `True True`, `'PROBE first\n'`. The executed equivalent did not remove the variable first; the false-case observed buffering establishes it was not effective in that case. The version above makes reruns independent of a pre-existing environment.
- **[A1] Apple, Xcode 27 release notes, current-generation primary docs:** https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes . Relevant sections: **Console / Known Issues (165098287)**, **Simulator / New Features (179846743)**, and **Testing**. Full structured page checked via https://developer.apple.com/tutorials/data/documentation/xcode-release-notes/xcode-27-release-notes.json .
- **[B1] xcbeautify maintainer README at pinned commit (latest source snapshot; August 2026, older than one month):** https://github.com/cpisciotta/xcbeautify/blob/513e4b12c3f6c965d1d3b66bd5cd9d635f03112d/README.md . Usage, `NSUnbufferedIO`, pipefail, GitHub Actions renderer.
- **[B2] xcbeautify implementation at the same commit:** https://github.com/cpisciotta/xcbeautify/blob/513e4b12c3f6c965d1d3b66bd5cd9d635f03112d/Sources/xcbeautify/Xcbeautify.swift#L26-L42 (flags), https://github.com/cpisciotta/xcbeautify/blob/513e4b12c3f6c965d1d3b66bd5cd9d635f03112d/Sources/xcbeautify/Xcbeautify.swift#L82-L95 (incremental reads / print output).
- **[C1] CircleCI / Constantin Jacob, firsthand CI experience, updated October 31, 2025 (older):** https://circleci.com/blog/xcodebuild-exit-code-65-what-it-is-and-how-to-solve-for-ios-and-macos-builds/ . Preboot advice and reported resource/timer interaction, not an Apple guarantee.
- **[R1] GitHub image maintainers, current preview announcement / September 16 base-OS update:** https://github.com/actions/runner-images/issues/14404 .
- **[R2] Bitwarden contributor's firsthand bootstatus/BackBoard report, October 2025 (older):** https://github.com/actions/runner-images/issues/12777#issuecomment-3401985595 .
- **[R3] GitHub maintainer's Xcode 26 VM/CoreSimulator diagnosis and suggested stable generations, November 2025 (older):** https://github.com/actions/runner-images/issues/13264#issuecomment-3496771593 and https://github.com/actions/runner-images/issues/13264#issuecomment-3497583041 .
- **[R4] 2024 firsthand runner initialization reports (older):** https://github.com/actions/runner-images/issues/9591#issuecomment-2054209653 (AX loading), https://github.com/actions/runner-images/issues/9591#issuecomment-2081064931 (clone/launchd/Accessibility failure).
- **[R5] GitHub maintainer's larger-runner workaround, July 2024 (older):** https://github.com/actions/runner-images/issues/9591#issuecomment-2222369299 .
- **[R6] Apparent image fix and retraction, April 2024 (older):** https://github.com/actions/runner-images/issues/9591#issuecomment-2051119699 and https://github.com/actions/runner-images/issues/9591#issuecomment-2051210559 .
- **[F1] fastlane's current pinned implementation of slide-to-type suppression:** https://github.com/fastlane/fastlane/blob/3d31dd995c222356bec72dcb5be515a4d1776ef1/fastlane_core/lib/fastlane_core/device_manager.rb#L236-L247 .
- **[F2] Older firsthand bootstrap-failure issue, cleanup/reset report (2018–2019):** https://github.com/fastlane/fastlane/issues/13190 and https://github.com/fastlane/fastlane/issues/13190#issuecomment-501247141 .
- **[F3] Contradictory/limited split-build workaround reports (older):** https://github.com/fastlane/fastlane/issues/13190#issuecomment-424034006 and https://github.com/fastlane/fastlane/issues/13190#issuecomment-480707342 .
- **[F4] fastlane tutorial/onboarding motivation, iOS 13 / 2019 (older):** https://github.com/fastlane/fastlane/issues/15742 .
- **[F5] Hardware-keyboard workaround, firsthand 2019 resolution (older):** https://github.com/fastlane/fastlane/issues/14685#issuecomment-488701972 ; merged upstream implementation history: https://github.com/fastlane/fastlane/pull/12829/files .
- **[M1] Mendoza / Tomas Camin, UI-test tool maintainer documentation, commit October 6, 2026:** https://github.com/Subito-it/Mendoza/blob/0d562601110bab102fcb2ad897eeb0aea4155e48/README.md#test-diagnostics-collection .
- **[S1] Secondary Stack Overflow answers, 2019–2021 (older):** https://stackoverflow.com/questions/59379891/dismiss-ios-13-keyboard-tutorial-when-running-on-a-fresh-simulator ; answer https://stackoverflow.com/a/70185587 identifies the tutorial view. Page access was blocked; answer bodies were checked through https://api.stackexchange.com/2.3/questions/59379891/answers?site=stackoverflow&filter=withbody .
- **[Q1] Search audit:** `ketch search '"XCTWaiter" "handleStalledWait"' --multi` and `ketch search '"XCTWaiter" "handleStalledWait" CI simulator' -b exa` found no source proving the requested CI-specific cause; the latter returned only https://github.com/firebase/firebase-ios-sdk/issues/6287 . Search absence is **not proof** that Apple has no internal diagnosis.
- **[Q2] Apple Forums leads, body/replies not verified:** https://developer.apple.com/forums/thread/805060 and https://developer.apple.com/forums/thread/691809 ; `ketch scrape` returned “Security verification in progress ... Invalid connection.” Search snippets identify the symptom but do not establish a remedy.
