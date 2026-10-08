# Making Blocklog's XCUITest suite fast and reliable (Xcode 27, iOS 27 simulator, SwiftUI)

## Question and short answer

What are the current best practices for fast, reliable XCUITest suites, and which easy wins cut this repo's UI suite time the most without losing its value as a whole-system check? This feeds ticket 10a (`.scratch/blocklog/issues/10a-ui-test-journeys.md`).

**Short answer.** The local log of the full 18-test run shows where the 721 s go, and three costs dominate: the per-test app launch, a hidden 1.0 s tax on every `waitForExistence`, and `ScreenshotTests`. Ticket 10a already attacks the first and third (fewer launches, screenshots out of the gate) and the animation idle waits. The one big win the ticket does **not** list is the `waitForExistence` tax: 116 calls cost 119 s (16.5 % of the run) because each call on an element that is already on screen still takes about 1.0 s. A four-line helper removes most of it. Everything else (parallel clones, libraries, test-plan tuning, build-once) is small or wrong for this repo. Details and exact changes are in the ranked list.

## Date, versions, method

- Checked 2026-10-08. Xcode 27.0 (27A266a) at `/Applications/Xcode.app`; iOS 27.0 simulator; XcodeGen 2.46.0 (`mise.toml`); repo `main` plus uncommitted work.
- Nothing was built or tested (the simulator is shared). "Verified (local)" means read from our own logs, scheme, justfile, workflow, or the installed Xcode 27 SDK headers and binaries. "Source" means taken from Apple docs, WWDC transcripts or release notes. Anything neither is marked `unknown` or `inference`.
- The measured baseline is `build/logs/test.log`, the 18-test run at 10:17–10:27 on 2026-10-08 (721 s on a busy shared Mac; 1 failure in `SettingsTests`, unrelated to timing). `build/logs/test-ui.log` (10 tests, 359 s, less load) gives a second sample. The CI numbers are from `gh run view 37789796552` (UI job).

## Where the time goes (verified, local)

Computed from the `t = …` step lines in `build/logs/test.log` (a script over "Waiting", "Wait for … to idle", and the launch lines):

| Cost | Local 18-test run (721 s) | Share | Notes |
| --- | --- | --- | --- |
| Launch to first user step (app launch, automation session, first idle) | 18 launches, median 19.5 s, sum about 354 s | up to 48 % | `LaunchTests` alone is 17.6 s (`test.log:749`). The less loaded `test-ui.log` run had a median of 9.7 s. The cost depends on host load. |
| `waitForExistence` calls | 116 calls, sum 119 s, min 1.00 s, median 1.02 s, max 1.07 s | 16.5 % | Every call took about 1.0 s even though every element was already there. See rec 2. |
| "Wait for … to idle" steps | 395 steps, sum 161 s; 352 of them are fast (median 0.16 s); 43 are over 1 s and add up to 85 s; none over 5 s | 22 % (12 % from the slow ones) | Animation and keyboard transitions. These shrink with animations off. The ranges overlap a little with launch idle. |
| `ScreenshotTests` (3 tests) | 44.5 + 24.3 + 68.1 = 137 s (`test.log:899,923,1202`) | 19 % | Design-review tool, not a gate check. |
| 60 s stall | "App animations complete notification not received" at t=36.95 → 97.46 s (`test-ui.log:106`) | one test, 130 s | The keyboard-up push, already fixed by dismissing the keyboard first. |

CI (run 37789796552, UI job): the "Build and test" step is 818 s. Tests are 681.6 s of it (83 %): 15 tests, about 45 s each. Slimming took 71 s and overlaps the build, and `build-for-testing` finished at 14:08:45, 90 s after the step started (`ci-test` lines in the run log). CI log lines are xcbeautify-formatted, so idle steps are not visible there.

Not repeated here: simulator slimming, boot stalls, compilation cache, job structure (see `docs/research/ci-efficiency.md`, `ci-ui-test-stall.md`, `simulator-resources.md`, `ios-ci-github-actions.md`).

## Ranked recommendations

Ranked by expected time saved per unit of effort. "Saving" is an estimate from the table above, not a measured result of the change.

### 1. Cut the launch count: 18 launches to 4–6 journeys, delete `LaunchTests` (already in ticket 10a)

- **Saving.** About 12 fewer launches. At the local medians that is roughly 85 s (quiet host) to 230 s (busy host), plus the 17.6 s of `LaunchTests`. In CI it removes about 12 × (20–60 s of per-test overhead that the ticket measured). This is the biggest single item and it is already in scope.
- **Effort.** Ticket 10a (hours). **Risk.** Longer tests fail later and retry costs a whole journey (`-retry-tests-on-failure` reruns the full journey). Mitigations are under rec 9.
- **Evidence.** Verified (local): each test relaunches (`Terminate com.gvanderclay.blocklog:<pid>` then `Launch` at every test start, `test.log:735`). Source: `XCUIApplication.launch()` terminates a running instance, `activate()` does not (`XCUIApplication.h:77`, Apple docs for `activate()`).
- **Do not go further.** Launching once per class or per run and resetting state in-app (via `class setUp` plus `XCUIApplication.activate()`, or a launch-argument or `app.open(url)` reset) would save at most 4–5 more launches (about 20–90 s) but breaks test isolation: one journey's leftover sheet, keyboard or in-memory rows would leak into the next, and a failure would cascade. With 4–6 journeys the launch cost is already small. `unknown`: no Apple source gives a recommended launch-reuse policy. Revisit only if the journeys count grows past about 8.

### 2. Stop paying about 1.0 s per `waitForExistence` on an element that is already present (not in the ticket; add it)

- **Saving.** Up to 119 s of the 721 s local run (16.5 %). After the journey merge the call count drops, but a journey still has dozens of them; expect 30–60 s per full run. In CI the per-call cost is probably the same (the cause is in XCTest, not the host); `unknown` until measured there.
- **Effort.** 15 minutes. **Risk.** None for correctness: the helper falls back to the real wait when the element is not there yet.
- **Evidence (verified, local).** Each log shows `Waiting 5.0s for "<id>" … to exist` and the first `Checking existence` line exactly 1.0–1.07 s later, in all 116 cases (`test.log:737`: 16.19 s → 17.20 s for an element that was on screen). So `waitForExistence` evaluates its predicate first after a 1 s poll tick; a plain `.exists` check is immediate (it logs `existsNoRetry`, and `tap()` shows `Find the "…" Button` about 0.1 s after the previous step). The reason inside XCTest is `unknown` (the framework is closed); the measurement is not.
- **Exact change.** Add `UITests/XCUIElement+Appears.swift` and call it everywhere instead of `XCTAssertTrue(x.waitForExistence(timeout:))`:

  ```swift
  import XCTest

  extension XCUIElement {
      /// True when the element is on screen. Checks first, because `waitForExistence` spends about 1 s
      /// before its first check even when the element is already there (measured in build/logs/test.log).
      @MainActor
      func appears(timeout: TimeInterval = 5) -> Bool {
          exists || waitForExistence(timeout: timeout)
      }
  }
  ```

  Then `XCTAssertTrue(app.buttons["exercisePicker.cancel"].appears(), …)`. In `XCUIApplication+Focus.swift` the `done.waitForExistence(timeout: 5)` after a tap is the same pattern and it sits in the hottest path (every keyboard use).
- **Also consider.** Xcode 16 added `XCUIElement.wait(for:toEqual:timeout:)` (Xcode 16 release notes; `XCUIAutomation.swiftinterface:21` in the Xcode 27 SDK; shown in WWDC25 session 344). Whether it has the same 1 s first tick is `unknown`; measure it before swapping. For the "does not exist any more" case, `waitForNonExistence(timeout:)` exists (`XCUIElement.h:60`); the same `!exists ||` guard applies.
- **Where a wait is unnecessary.** After a tap that triggers navigation, XCTest already waits for the app to go idle before the next query (log: `Wait for com.gvanderclay.blocklog to idle` before every `Tap`). With animations off (rec 3) a following `tap()` usually finds its element without an explicit wait. That is the kind of removal to try, one journey at a time. Evidence that `tap()` waits for existence of its target by itself: `unknown`; do not remove a wait before an async result (for example an import or a saved workout).

### 3. Animations off under `-ui-testing` (already in ticket 10a; this is how, and why it works)

- **Saving.** At most the 85 s of idle steps over 1 s (12 % of the run), and it removes the 60 s "animations complete notification not received" stall class entirely. The 352 short idle steps (median 0.16 s) are run-loop idle, not animation, and do not go away. Realistic total: 40–85 s locally. `unknown` until measured after the change.
- **Effort.** 20 minutes. **Risk.** Low. Production is untouched (guarded by the existing `-ui-testing` argument). The UI no longer exercises animation paths, so animation bugs (a row that never removes) surface only in `just screenshot` or by hand; say so in `docs/design.md` motion notes.
- **What actually removes XCTest's idle wait (verified, local binary strings).** `XCTAutomationSupport.framework` (inside the simulator platform's `PrivateFrameworks`) implements the animation idle check by swizzling `UIViewAnimationState`'s `animationDidStart:` and `animationDidStop:finished:`. Its own error strings say: "Monitoring for idle animations is not available because the UIViewAnimationState class is missing the instance method @selector(animationDidStart:)". `XCUIAutomation` then logs "App animations complete notification not received, will attempt to continue." when that never arrives. Inference: the "animations idle" part of XCTest's quiescence wait follows UIKit view animations (sheets, navigation pushes, keyboard, alerts, `UIView.animate` blocks), which SwiftUI uses for its presentations. The strings do not mention Core Animation layer animations or SwiftUI `withAnimation`. So the lever that matters for idle time is the UIKit one.
- **Candidates, ranked for this app (a SwiftUI `App` with no `AppDelegate`):**
  1. `UIView.setAnimationsEnabled(false)`. Apple: "If you disable animations, code inside subsequent animation blocks is still executed but no animations actually occur… This method affects only those animations that are submitted after it is called" (Apple docs, `UIView.setAnimationsEnabled(_:)`). It is the flag that leaves `UIViewAnimationState` with nothing to wait for. Real apps do exactly this behind a launch argument: Hackers (a SwiftUI app) `skipAnimations` in `AppDelegate.swift`; Firefox iOS `LaunchArguments.DisableAnimations` in `UITestAppDelegate.swift` (file last changed 2026-08-14); WordPress Aztec `NoAnimations` (older). Secondary sources, but all three are production code. Whether it also stops the SwiftUI-owned animations on iOS 27 (for example `withAnimation` row insertion) is `unknown` and that is fine: that part is covered by candidate 2.
  2. A root `.transaction { $0.animation = nil; $0.disablesAnimations = true }` on `RootView` under `-ui-testing`. Apple: `transaction(_:)` "applies the given transaction mutation function to all animations used within the view" (Apple docs); `Transaction.disablesAnimations` is a settable `Bool` (`var disablesAnimations: Bool { get set }`, docs). This removes SwiftUI's own animations (`withAnimation` in `SetRow`, `WorkoutScreen`, `FinishSheet`, and `.animation(_:value:)` in `ExercisePicker.swift:35-36`). It cannot affect UIKit-driven presentations, which is why candidate 1 is needed too. Effect on explicit `withAnimation` from a descendant: `unknown`; measure.
  3. `.symbolEffectsRemoved(…)` is wired to `reduceMotion` (`FinishSheet.swift:87`, `SetRow.swift:102`). `EnvironmentValues.accessibilityReduceMotion` is get-only (`var accessibilityReduceMotion: Bool { get }`, Apple docs), so a root `.environment` override is not possible. To stop symbol bounces under test, pass `reduceMotion || uiTesting` where it is read. Optional; bounces are CA effects and are probably not in the idle monitor (inference).
  4. Raising the window's `CALayer.speed` (Firefox sets `UIWindow.keyWindow?.layer.speed = 100` in `didFinishLaunching`). Skip: there is no `AppDelegate` here and the window does not exist in `App.init`. It only helps layer animations that candidates 1–2 should already remove.
  5. Launch-environment flags: `XCUIApplication.launchArguments` and `launchEnvironment` only deliver data to the app (`XCUIApplication.h:102`); they do not touch XCTest. They are how the app learns it is under test, nothing more.
- **Exact change** (in `App/BlocklogApp.swift`; the architecture rules put rules in `App/Logic`, but this is one app-start line, not a rule, so a tiny helper there is also fine):

  ```swift
  init() {
      let uiTesting = CommandLine.arguments.contains("-ui-testing")
      if uiTesting { UIView.setAnimationsEnabled(false) }
      …
  }
  var body: some Scene {
      WindowGroup { RootView().transaction { if uiTesting { $0.animation = nil } } }
  ```

  (store `uiTesting` as a `let` on the struct, since `body` cannot read `init`'s local.) Keep `disablesAnimations` out of the first attempt and add it only if row insertions still animate.
- **Does XCUITest have its own setting? No public one (verified, local).** A search of the Xcode 27 `XCUIAutomation` and `XCTest` headers (`Headers/*.h`) for idle, animation, quiescence and timeout finds nothing: `XCUIApplication` has `launch`, `activate`, `terminate`, `launchArguments`, `launchEnvironment`, `state`, `waitForState:timeout:`; `XCUIElement` has `waitForExistence`, `waitForNonExistence`, and `wait(for:toEqual:timeout:)` (Swift overlay). The private classes do have switches (`XCUIApplicationProcess shouldSkipPreEventQuiescence` / `shouldSkipPostEventQuiescence`, `_idleAnimationWaitEnabled` in the `XCUIAutomation` binary). They are private API; do not use them, and Apple's Xcode 15–27 release notes list no replacement. `unknown`: whether Apple plans one.
- **How to prove it (ticket's acceptance line).** After the change, run `just test-ui`, then list every idle step over 1 s:

  ```bash
  python3 - <<'E'
  import re
  L=open('build/logs/test-ui.log',errors='ignore').read().split('\n')
  t=re.compile(r'^\s+t =\s+([\d.]+)s \s*(.*)')
  ev=[(float(m.group(1)),m.group(2)) for l in L if (m:=t.match(l))]
  for i,(tm,x) in enumerate(ev[:-1]):
      if x.startswith('Wait for') and 'idle' in x and ev[i+1][0]-tm>1: print(round(ev[i+1][0]-tm,2),x)
  E
  rg -c "animations complete notification not received" build/logs/test-ui.log
  ```

  Baseline to beat: 43 steps over 1 s totalling 85 s in `test.log`.

### 4. `ScreenshotTests` out of the gate (already in ticket 10a)

- **Saving.** 137 s of 721 s locally (19 %) and about the same share in CI (13 s in the earlier 2-test CI run, now three tests). **Effort.** 5 minutes. **Risk.** Screenshot code can break unnoticed; `just screenshot` runs it on demand, and a design checkpoint covers it. Add one sentence to `AGENTS.md` (ticket does).
- **Evidence.** Verified (local): `just screenshot` already selects `-only-testing:BlocklogUITests/ScreenshotTests` (justfile). Source: `xcodebuild` man page: "`-only-testing` has precedence over `-skip-testing`", test identifiers have the form `Target[/Class[/Method]]`.
- **Exact change** (`justfile`): add `-skip-testing:BlocklogUITests/ScreenshotTests` to the `test` and `test-ui` recipes, and in `ci-test` change the extra array to `[[ "{{scheme}}" == BlocklogUI ]] && extra=(-retry-tests-on-failure -test-iterations 2 -skip-testing:BlocklogUITests/ScreenshotTests)`. Leave `test-one` and `screenshot` unchanged. `build-for-testing` still compiles the file; that is fine.
- Caveat: with `ScreenshotTests` skipped, `Blocklog.xcscheme`'s `Blocklog` scheme still includes the class when run from Xcode; only the CLI recipes skip it. If that matters, a dedicated `BlocklogScreenshots` scheme (XcodeGen `schemes:` entry) is the cleaner split but is not worth it now.

### 5. Test timeouts so a stall costs minutes, not the whole step (new, cheap)

- **Saving.** 0 s on green runs. It bounds the bad case: the stall in `test-ui.log` cost 60.5 s; a hung journey currently runs until the CI step limit (`timeout-minutes: 16` on "Build and test"). **Effort.** 2 minutes. **Risk.** A journey that legitimately runs longer than the allowance is killed and reported as a failure (then retried); set generous values.
- **Evidence.** Source: `xcodebuild` man page, installed Xcode 27: `-test-timeouts-enabled [YES|NO]`, `-default-test-execution-time-allowance seconds`, `-maximum-test-execution-time-allowance seconds`. WWDC20 session 10221: allowances are rounded up to whole minutes, minimum 60 s ("for a value like 100 seconds, it would be rounded up to 120"), the default when enabled is 10 minutes per test, and the timer restarts for each test. Verified (local): neither flag is in `justfile` today.
- **Exact change.** Define `timeouts := "-test-timeouts-enabled YES -default-test-execution-time-allowance 180 -maximum-test-execution-time-allowance 300"` next to `no_diag` in the justfile and add `{{timeouts}}` to `test`, `test-ui`, `test-one` and the `xcodebuild test-without-building` call in `ci-test`. Pick 180 s because a journey of about 15 steps at 3–6 s each is 60–90 s; adjust after the first measured run. Per-journey override: `executionTimeAllowance = 240` in `setUp` (also minute-rounded).

### 6. Keep `-collect-test-diagnostics never`, code coverage off, one simulator (already true; do not change)

- **Verified (local).** `no_diag := "-collect-test-diagnostics never"` is defined at `justfile:9` and passed by every local recipe and by the `ci-test` recipe's `test-without-building` call, so CI has it too. Code coverage is off: none of the three generated schemes (`Blocklog.xcodeproj/xcshareddata/xcschemes/*.xcscheme`) sets `codeCoverageEnabled` (only `onlyGenerateCoverageForSpecifiedTargets = "NO"`), and XcodeGen defaults `gatherCoverageData` to false (XcodeGen `ProjectSpec.md:890`). Passing `-enableCodeCoverage NO` would change nothing. Whether coverage would slow UI tests if enabled is `unknown` (no source measures it).
- Retry on failure is CI-only (`-retry-tests-on-failure -test-iterations 2`, `ci-test`). With journeys, a retry reruns one whole journey (1–2 min); keep it, since a single retry has already hidden cold-simulator flakes.

### 7. Screen recording: measure before deciding (new, experiment only)

- **Evidence.** Source: Xcode 15 release notes: "XCTest now supports automatic screen recordings in addition to screenshots… enabled by default (in favor of screenshots). They can be disabled in the test plan or the scheme's Test action options." XcodeGen exposes it as `test.preferredScreenCaptureFormat` (`screenshots` or `screenRecording`, default `screenRecording`; `ProjectSpec.md:1087`). The Xcode 27 `IDEFoundation` binary has the test-plan keys `preferredScreenCaptureFormat`, `uiTestingScreenshotsLifetime`, `systemAttachmentLifetime`, `userAttachmentLifetime`, and the lifetime values `keepAlways`, `deleteOnSuccess`, `keepNever` (strings in the binary; the exact JSON spelling of the values is `unknown`, create a plan in Xcode and read the file). Verified (local): our schemes set none of them, so we run with the default recording. A failing run's result bundle holds an mp4 (`build/results/test-20261008-101449.xcresult`, exported with `xcresulttool export attachments`, 1 mp4 among the attachments); a passing run's bundle is small (`test-ui-20261007-225438.xcresult`, 2.2 MB, only our six screenshots), so videos of passing tests are not kept.
- **Open question.** Whether the recording itself slows each step is `unknown`; no Apple source quantifies it. The experiment costs 10 minutes: run `just test-one BlocklogUITests/<one journey>` three times with the default and three times with `preferredScreenCaptureFormat: screenshots` in the scheme (add under `test:` in `project.yml`), compare wall time. Keep recording on if the saving is under about 5 %, because a video of a 90-second journey is the best failure diagnostic we have (see rec 9).

### 8. Parallel testing and splitting CI: do not use simulator clones; split into two jobs only if needed after 10a

- **Evidence.** Source: WWDC20 session 10221: parallel distributed testing "will distribute tests to each run destination by class", one class at a time per device, allocation non-deterministic. So parallelism is per class; with journey-sized classes there are at most 4–6 units, of uneven length, so the best case is bounded by the longest journey. Verified (local): the `xcode-27` runner is arm64 with 3 cores and 7 GB (`docs/research/ios-ci-github-actions.md:21`); one slimmed simulator measured 76 processes and 552 MB on it (`slimmed in 71s: … 76 processes, 552 MB`, run 37789796552). Two clones fit in memory on paper but compete with `xcodebuild` and the test runner for 3 cores; the UI suite is mostly waiting, so CPU may be fine. `unknown`: no measurement of two clones on this runner. Source (older, firsthand): runner-images issues #9591 and #12777 report clone and launchd failures on hosted macOS (cited in `ci-ui-test-stall.md` and `simulator-resources.md`). Raw `simctl clone` does not carry simslim's profile; `simslim clone` does (`simulator-resources.md` section on clones, upstream PR #18). Xcode 27 release notes add a note that parallel simulators may not show in Device Hub (cosmetic).
- **Recommendation.** Keep `-parallel-testing-enabled NO` (the justfile has it everywhere). After 10a, if the CI UI job is still over 7 minutes, split by class into two jobs (a matrix on `-only-testing:`/`-skip-testing:` lists), not clones. Each job repeats about 90 s of build plus slim (above), so the saving is about (tests / 2) minus 90 s; it only pays if the tests step is over about 4 minutes. Minutes are free on a public repo (`ci-efficiency.md` section 3). Risk: two jobs double the simulator-boot lottery (see `ci-ui-test-stall.md`).

### 9. Keep journeys diagnosable (design guidance for 10a)

- **Evidence.** Source: Apple's WWDC19 session 413 frames the test pyramid: unit tests are the foundation, UI tests sit on top "to strike a balance between thoroughness, quality and execution speed". WWDC25 session 344: "Generally, your test suite will have more unit tests than UI tests… But UI automation tests let you see how your app looks, behaves, and integrates with the rest of the system." Both match ticket 10a's split (rules in unit tests, wiring in journeys). `XCTContext.runActivity(named:)` is documented to "group low level actions, such as typing and tapping, into high level tasks" and produces an activity hierarchy in the report (`XCTContext.h:20-57`, Xcode 27 SDK); the Xcode test report and the video timeline show the failing activity (WWDC23 session 10175).
- **How big is too big.** `unknown`: no Apple source gives a size. Practical limits derived from our logs: an average step costs 3–5 s locally (189 user actions in 721 s with launch removed), so a journey of 20 activities is about 60–90 s. Keep each activity to one screen's worth of steps, name it after the user outcome ("Finish the workout and see Workout 1"), and assert inside the activity that makes the claim, not at the end. A failure then reads as one activity name plus the video position.
- **Rules that keep failures local.** (a) `continueAfterFailure = false` (already set), so a failed step stops the journey instead of cascading into misleading later failures. (b) Do not use `XCTSkip` to jump over a step that "might not apply": it hides lost coverage; use it only for a documented environment limit (for example no hardware keyboard), and then the skip reason shows in the report. (c) Journeys that need a state (a finished workout for "previous numbers") create it through the UI inside the same journey, as 10a plans. A launch-argument seed (the app writes known rows through its `App/Logic` functions under `-ui-testing`) could shorten journeys 3–5 by skipping setup taps, but it trades away part of the whole-system check; leave it for later if journey time is still high.
- **Retries.** `-retry-tests-on-failure -test-iterations 2` stays on CI: a retried journey that passes is reported as recovered (`scripts/ci-report.py` already handles it), so flakiness stays visible.

### 10. Libraries: none worth adding for speed now

All of these need the user's permission first (architecture rule 6). Stats from the GitHub API on 2026-10-08.

| Library | State | Fit here | Verdict |
| --- | --- | --- | --- |
| `pointfreeco/swift-snapshot-testing` 1.19.6 (2026-09-21, MIT, 4.4k stars) | active | Renders a view in the unit-test host and diffs against a stored image, with no app launch, no XCTest idle wait and no `-ui-testing`. It could replace `ScreenshotTests`'s regression value (light, dark, large-text variants) at unit-test speed. Costs: reference images in the repo, re-record when iOS rendering changes, no real navigation. | Optional later, if the screenshot suite proves valuable as a regression check. Not a gate speed-up today because `ScreenshotTests` leaves the gate anyway. |
| `nalexn/ViewInspector` 0.10.5 (2026-09-30, MIT) | active | Inspects SwiftUI view structure in unit tests. | **No.** Architecture rule 10 says tests never check view internals, and rule 1 puts logic in `App/Logic` where plain unit tests already reach it. |
| `kif-framework/KIF` 4.0.2 (2026-07-27) | active | Drives the UI in-process from a unit-test target ("the magic of KIF is that it allows you to drive your UI from your unit tests", README), so there is no IPC, no quiescence wait and no relaunch per test. Uses accessibility labels and, by design, private UIKit access. | Fast in principle; `unknown`: SwiftUI support on iOS 27, Swift 6 strict concurrency and `App` lifecycle hosting. Replacing XCUITest is a large change for a suite that 10a just shrank to 5 journeys. Skip. |
| `google/EarlGrey` 2.2.2 (last release 2022-06-07) | stale | XCUITest-based again. | No. |
| `mobile-dev-inc/Maestro` cli-2.11.0 (2026-09-29) | active | YAML flows through the accessibility layer; no Swift. Same driver-over-accessibility architecture as XCUITest, so not inherently faster on a simulator (`unknown`; not measured). | No. A second tool and a second language for no measured gain. |
| Appium XCUITest driver 12.16.0 | active | Adds WebDriverAgent and HTTP in front of XCUITest. | No: strictly slower than native XCUITest. |

Tooling already in place and enough: `xcbeautify` 3.2.1 with `NSUnbufferedIO=YES` (`ci-test`), `xcresulttool`, `xcodebuild -enumerate-tests` (Xcode 15 notes) for listing tests when building skip lists.

### 11. Other small items (optional, each under 10 minutes)

- **Typing.** `typeText` is synthesized per character; our strings are short (`"10"`, `"curl"`) and a 1 s step includes its idle wait (`test.log:773`). Nothing to win; do not replace it with pasteboard tricks.
- **Queries.** Verified (local): the suite uses identifiers almost everywhere, one `matching(NSPredicate)` over `buttons` (`ExercisePickerTests.swift:110`), and `swipeUp` loops only in `WorkoutFlowTests.swift:138` and `ScreenshotTests`. Source: WWDC25 session 344 best practices: prefer accessibility identifiers, keep queries as short as possible (`app.staticTexts["Collection-1"]`, not `app.scrollViews.staticTexts[…]`), use `firstMatch` for dynamic content. Cost of a deep query or snapshot: `unknown` (no Apple number); our logs show `Find the "<id>" Button` taking 0.05–0.15 s per step, so there is nothing to gain here. Keep new journey code on shallow identifier queries. Avoid scroll-until-visible loops on lazy rows by searching (`exercisePicker` search field) or using the `Menu`, which is also what a user does.
- **Stray file.** `UITests/TmpBackupManual.swift` is untracked and holds a manual driver (`testA_export`) that launches without `-ui-testing` and is not part of the 18 counted tests today; if it is still there when 10a lands, it would join the gate. Delete it before 10a (it says "deleted afterwards" itself).
- **Build once, test many.** Verified (local): `ci-test` already runs `xcodebuild build-for-testing` then `test-without-building`, in parallel with simulator boot and slimming. `just test`, `test-unit`, `test-ui` use plain `test` (build plus test in one invocation), which is the same work locally. Splitting the local recipes gains nothing; DerivedData is stable at `build/DerivedData`.
- **Idle simulator wait at first launch.** Not tuned; the 1.6 s vs 11.9 s "Setting up automation session" difference between a quiet and busy host (`test-ui.log` vs `test.log:742`) is host load, not app cost. Do not time UI tests while another heavy job holds the simulator.
- **Hardware keyboard and predictive text.** The app's keyboard toolbar (`keyboard.done`) needs the software keyboard, whose first bring-up caused the cold-simulator flake documented in `XCUIApplication+Focus.swift`. Settings to turn off autocorrect/predictive bar via `defaults` in the simulator are widely quoted but `unknown` on iOS 27; not verified, so not recommended.

## Proposed order for ticket 10a

1. Add `appears()` (rec 2) first; it is independent and gives the largest "free" saving.
2. Animations off (rec 3), then run the measurement script to confirm no idle step over 1 s.
3. Merge to journeys and delete `LaunchTests` (rec 1) with activities (rec 9).
4. Skip `ScreenshotTests` (rec 4) and add the timeouts (rec 5).
5. Record before/after: local `just test-ui` wall time, the table at the top of this file regenerated from `build/logs/test-ui.log`, the CI UI job time. Then decide on rec 7 (recording) and rec 8 (job split) from the numbers.

Expected local effect, as a rough estimate only (components overlap): from 721 s to roughly 200–300 s on the same busy host (about 5–6 launches, no screenshots, no 1 s tax, short idle waits). CI is expected to land near the ticket's 7-minute target if per-test overhead falls as it does locally; `unknown` until a run exists.

## Unknowns

- Whether `UIView.setAnimationsEnabled(false)` plus a root `.transaction` removes every idle wait over 1 s on iOS 27 (no run was allowed here).
- Whether `XCUIElement.wait(for:toEqual:timeout:)` has the same 1 s first tick as `waitForExistence`.
- The cost of screen recording per UI test, and the cost of code coverage if enabled.
- Two simulator clones on the 3-core, 7 GB `xcode-27` runner.
- A recommended maximum journey length (no Apple source).
- The JSON spelling of the test-plan attachment lifetime values (strings exist in `IDEFoundation`; create a plan in Xcode to read the exact keys).

## Sources

- Local, Xcode 27.0 (27A266a): `XCUIAutomation.framework/Headers/XCUIApplication.h` (lines 77, 102), `XCUIElement.h` (lines 56–60), `XCUIAutomation.swiftinterface:21`, `XCTest.framework/Headers/XCTContext.h`, `XCTestCase.h`; `man xcodebuild` and `xcodebuild -help` (timeouts, `-skip-testing`, `-enableCodeCoverage`, retry flags); `strings` of `XCTAutomationSupport` and `XCUIAutomation` (animation idle monitor) and `IDEFoundation` (test-plan keys).
- Local repo: `justfile`, `.github/workflows/ci.yml`, `project.yml`, `mise.toml`, `App/BlocklogApp.swift`, `UITests/*`, `Blocklog.xcodeproj/xcshareddata/xcschemes/*.xcscheme`, `build/logs/test.log`, `build/logs/test-ui.log`, `build/results/*.xcresult`; CI run 37789796552 (`gh run view --log`).
- Apple documentation (developer.apple.com/documentation JSON): `UIView.setAnimationsEnabled(_:)`, `UIView.areAnimationsEnabled`, SwiftUI `Transaction.disablesAnimations`, `View.transaction(_:)`, `EnvironmentValues.accessibilityReduceMotion`, `XCUIApplication.activate()`, `XCUIElement.waitForExistence(timeout:)`, "Organizing tests to improve feedback".
- Apple release notes: Xcode 15 (screen recordings on by default, test enumeration), Xcode 16 (`wait(for:toEqual:)`), Xcode 26 (runtime issue detection in tests), Xcode 27 (crash severity in test plans, parallel-simulator Device Hub note), at `developer.apple.com/documentation/xcode-release-notes/`.
- WWDC: 2019 session 413 "Testing in Xcode" (test pyramid, parallel on cloned simulators); 2020 session 10221 "Get your test results faster" (time allowances, parallel by class); 2023 session 10175 "Fix failures faster with Xcode test reports"; 2025 session 344 "Record, replay, and review: UI automation with Xcode" (identifiers, concise queries, `wait(for:toEqual:)`, more unit than UI tests).
- Secondary (production code, not Apple): `weiran/Hackers` `App/AppDelegate.swift` (`skipAnimations`), `mozilla-mobile/firefox-ios` `firefox-ios/Client/Application/UITestAppDelegate.swift` (`DisableAnimations`, `layer.speed = 100`), `wordpress-mobile/AztecEditor-iOS` `Example/Example/AppDelegate.swift`.
- Libraries: GitHub repository and release metadata for swift-snapshot-testing, ViewInspector, KIF, EarlGrey, Maestro, appium-xcuitest-driver (API queries on 2026-10-08); KIF README; XcodeGen `Docs/ProjectSpec.md` (test action options).
