# Simulator resources on an 8 GB shared Mac

## Question and short answer

How can we cut iOS Simulator and Xcode test CPU/memory on this shared 8-core, 8 GB Mac without making tests less valid?

**Apply full SimSlim to the dedicated iPhone 17, disable Xcode test parallelism in every local recipe, and prevent unrelated heavy work from competing with the one permitted simulator.** SimSlim is a credible, reversible way to remove the measured background workload, with upstream iOS 27 evidence, but it is not an Apple-supported promise that altered simulators preserve every test behavior. At the checked allowlist, the required keyboard, automation/accessibility, local-notification, audio, storage and screenshot infrastructure is not among the labels SimSlim disables, so the exact proposed command needs no `--except` or `--keep`. Compare the full suite and screenshots against stock before treating source-level compatibility as runtime proof. Keep the single simulator warm within a project's work batch; shut it down when that batch is finished and the Mac needs the RAM. Do not keep two stock simulators warm on this machine. [L1][L2][S1][S2][S5][S6][A1]

Checked **2026-10-07**. Local toolchain: **Xcode 27.0 / 27A266a**, **iOS 27.0 simulator / 24A434 / arm64**. Repo baseline: **`c451ddf25225fc55dff307f1125573ea27a8cc78`**. SimSlim source: **`2d4f6361dc6be0eec330f81ecfa558a4abe6f618`**, October 4, 2026; latest published release **v0.11.0**, September 24, 2026, release commit **`e752a72898ca69f703c74dc79b7b047a4f2093a3`**. MobAI CI source: **`246fcf4ce13e74948f1ad6194dc60d4647fa967f`**. Sources older than the last month are marked below. [L0][S0][C2]

No simulator was booted, shut down, erased or changed; nothing was installed and no builds/tests were run. Commands in this report are **proposals**, except the explicitly identified read-only verification commands. **Verified for Xcode 27** means the local CLI supports the syntax, not that a performance benefit or test equivalence was measured. [L0]

## Evidence and the actual local gaps

The task supplied these measurements: load average **218 / 179 / 169**, **3.0/4.0 GB swap used**, **43 million swapouts since boot**; one iPhone 17 simulator, about **200 processes / 4.1 GB summed RSS / 264% CPU**. Largest reported processes include the app (294 MB), SpringBoard (201 MB), MercuryPosterExtension (199 MB), Spotlight (161 MB), WidgetRenderer (150 MB), sirittsd (116 MB), HealthBalanceWidgetExtension (103 MB), and about nine 96–99 MB wallpaper extensions. These are **supplied observations, not independently reproduced**. Their overlap makes wallpaper a good target, but summing RSS double-counts shared mappings; do not equate 4.1 GB RSS with SimSlim's phys_footprint figures or promise a 0.9 GB reduction just from the poster RSS sum. [L3][S1][S3]

`~/.pi/agent/bin/sim-lock` already serializes commands under `/tmp/xcode-heavy.lock`, shuts down other booted devices once it acquires the lock, and leaves its own device booted afterward. This prevents two participating simulator steps from executing together, **not unrelated agents/processes from consuming memory**, and not Xcode-created testing clones in another device set. The script enumerates the default `simctl list devices booted` set only; SimSlim documents Xcode's separate `testing` set. Alternating projects with different UDIDs will therefore repeatedly shut down/reboot each other's device. [L2][S1][S7]

Current `justfile` findings (read working tree and committed baseline):

- `test`, `test-unit`, `test-ui`, `test-one` and each `screenshot` iteration **do not** pass `-parallel-testing-enabled NO`. Do not assume the machine lock prevents Xcode itself from spawning parallel workers/clones. [L1][A1][S7]
- `ci-test` **already** uses `-parallel-testing-enabled NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, stable `build/DerivedData`, `build-for-testing` then `test-without-building`, and `-collect-test-diagnostics never`. These are not new CI savings. Local tests also already disable long diagnostics. [L1]
- `_xcb` does not disable compiler indexing or bound build operations. `screenshot` uses ordinary `test` three times with the same DerivedData, not a guaranteed three full recompiles, but it could build once and execute three times. [L1][A1][A3]
- `ci-test` waits for `bootstatus -b` **before** compilation. Contrary to its comment's possible reading, it does not currently overlap boot with build. On a thrashing Mac, this is a defensible peak-memory trade-off; do not add boot/build overlap until pressure is controlled. [L1][L3][C1]
- `run` attempts to open Simulator.app; tests do not explicitly do so. The recipe comment says this installation has no Simulator.app, but that comment alone is not a verified inventory claim. [L1]

## 1. Trimming simulator services

### SimSlim: what it actually changes

At the pinned source, SimSlim has a finite allowlist of roughly 170 launchd labels grouped into 15 categories. `--except` **keeps** entire categories; `--keep` keeps specific labels the tool would otherwise disable. Overlapping labels remain enabled if any excepted category needs them. A bare `simslim on UDID` disables every category; that is the requested Blocklog profile here. [S1][S2]

Its current normal `on`/`off` implementation prefers writing the per-device override store while the device is shut down, then boots once and reads back `launchctl print-disabled system`. If a booted device already matches the profile it returns without rebooting; otherwise it shuts down first. If offline-store writing fails or is ignored, it falls back to individual `simctl spawn ... launchctl` transitions. That store is explicitly a **private CoreSimulator detail** in the implementation; the fallback and readback reduce risk, not the private nature of it. `on --no-reboot` instead runs `disable` plus `bootout` for each selected live service, checks overrides, and leaves extra preexisting disables alone. [S4]

The underlying manual example is:

```sh
# Examples only: these change the targeted simulator, not the host.
xcrun simctl spawn "$udid" launchctl disable system/com.apple.PosterBoard
xcrun simctl spawn "$udid" launchctl bootout system/com.apple.PosterBoard
# Repeat, if intentionally selected, for com.apple.chronod.
```

`disable` prevents subsequent loading; it is not a reliable way to evict an already running service. `bootout` removes the loaded job; do not boot out the entire `system` domain. Apple documents both subcommands in the installed host man page, and SimSlim's implementation uses precisely these service targets. **Unknown:** the same label's presence and effectiveness in this local iOS 27 device; no live `launchctl` query or mutation was executed. Host launchctl documentation is not an iOS runtime compatibility guarantee. [L4][S2][S4]

### Persistence, rollback and iOS 27 support

SimSlim accepts persistent overrides on iOS **18.5 and later**, using a numeric runtime-version check, not an Xcode-version allowlist. Older runtimes use session-only `--no-reboot`. Upstream PR #18 reports successful persistent overrides on **iOS 27.0** and demonstrates that **raw `simctl clone` does not preserve them**. PR #17 reports a slim iPhone 17 Pro / iOS 27.0 at **64 processes / 961.8 MB**, but that is an author's example, not a repeatable benchmark of this Mac/app. This establishes real iOS 27 experience; it does **not** establish a full Xcode 27 + Blocklog + WDA test matrix. [S4][S5][S6]

Overrides persist across same-device shutdown/reboot on the same Mac according to upstream. `simslim off UDID` restores **SimSlim-managed labels** and reboots, not every arbitrary mutation someone else made. Erasing/recreating, a new runtime/device, or moving/restoring to another Mac invalidates the presumed profile. Raw `simctl clone` comes up stock; current `simslim clone` explicitly reapplies its managed profile and repairs clone paths. Use a **separate disposable simulator** for experiments, not erase as rollback on a simulator with useful app data. [S1][S4][S5]

Latest release v0.11.0 includes the offline fast path for already-booted devices and a pool of eight fallback spawns. Release notes acknowledge that the previous shell-batching implementation never worked because iOS runtimes do not ship `/bin/sh`. Avoid copied recipes using `simctl spawn UDID /bin/sh -c ...`; perform loops in the **host shell**. Upstream issues also demonstrate real regressions from overly broad service removal: blank share sheets when `sharingd` was disabled, and purchase-sheet failure even with earlier versions' `--except store`. Both have targeted repairs at the pinned version. These are reasons to pin and inspect the profile, not regard a successful boot or `doctor` result as proof of feature equivalence. [S0][S8][S9]

### Recommended concrete profile for Blocklog's iPhone 17

**Use the full slim profile**, as requested: all fifteen categories off, no broad category exceptions. The exact dedicated UDID supplied by the orchestrator is `92848921-A0FA-4AEF-BD4A-C035637CA6EE`. At the checked version, none of the specifically required infrastructure identified below is a SimSlim-disableable label, so **there is no justified `--except` or `--keep` item to add**. This is a source-backed selection, not a claim that every transitive dependency has been runtime-proven. [S2][L5][L6]

```sh
# Proposal after approval and pinned installation; not executed here.
simslim on 92848921-A0FA-4AEF-BD4A-C035637CA6EE
```

This disables `widgets,siri,search,icloud,store,pim,web,family,health,photos,apps,messaging,connectivity,telemetry,other`, including remote push, Siri/TTS, wallpaper/widget/Live Activity providers and the other catalogued services. Do not keep `apsd` just for local notifications, keep all of `store` just for AVAudioSession, or keep all of `icloud` just for a local SwiftData store. These are different capabilities; the precise essential declarations checked below are outside the disable allowlist. The catalog also protects `com.apple.sharingd` automatically; no keep flag is needed for that label. [S2][S11][L5]

The upstream 4.0 → 0.9 GB result makes this the largest plausible simulator-specific saving, but its measured iOS 26.5 category deltas cannot be added and are not a promise for this iOS 27 device/app. Upstream iOS 27 slim use is documented; complete Blocklog and WDA equivalence remains **unknown** until tested. There is no need to preserve unneeded features solely for hypothetical future work, but a future actual HealthKit, Photos picker, Spotlight, Siri, CloudKit, push, StoreKit, widget or Live Activity requirement must restore its real dependencies. Ticket 13 explicitly excludes Live Activities. [S1][S3][S5][S6][L6]

If the full slim acceptance experiment identifies a required **allowlisted** service, retain that specific label with `--keep`, not its whole category. For example, a demonstrated speech dependency would justify keeping its specific speech label, whereas XCUITest's use of accessibility alone does not establish that `sirittsd`, `voiced` or `voicebankingd` is necessary. **Unknown:** a complete VoiceOver/speech dependency graph for iOS 27; full slim should not be labelled a VoiceOver-speaking configuration without checking it. The requested functional test infrastructure and actual spoken-accessibility testing are not identical coverage claims. [S2][L5]

### Services needed by this app and test harness

| Capability | What the checked source establishes | Validity guard / iOS 27 status |
|---|---|---|
| XCUITest, WDA, accessibility and screen composition | SimSlim's disable allowlist contains no testmanager, accessibility, SpringBoard or backboard labels. Local runtime plists identify `com.apple.SpringBoard`, `com.apple.backboardd`, `com.apple.accessibility.axremoted` and accessibility asset/audit services. | Never manually disable these, CoreSimulator/launchd, runningboard, installation or automation services. Absence from the allowlist is source-verified; a full slim XCUITest/WDA pass on this Mac is **unknown**. [S2][L5] |
| Text input | Existing UI tests call `typeText`. The allowlist has no keyboard, InputUI or KeyboardArbiter label. Local runtime has `com.apple.TextInput.kbd` and `com.apple.fullkeyboardaccess`. | Keep InputUI and KeyboardArbiter, keyboard/input daemons and accessibility services intact. Do not put them in `--keep`: this CLI rejects keeps outside its disable allowlist. A text-entry/keyboard-toolbar acceptance check is still necessary; absence of a name is not a complete dependency audit. [L1][L5][S2][S10] |
| Local notifications / rest timer | Ticket 13 specifies `UNUserNotificationCenter`, not remote push, and excludes Live Activities. Local runtime has `com.apple.usernotificationsd`; this label is not in SimSlim's allowlist. | Do not disable notification/BulletinBoard/SpringBoard services. `apsd` is catalogued as remote push, not a justification to disable local-notification infrastructure. The full command disables `apsd`, while leaving `usernotificationsd` untouched; local delivery still needs actual validation. The real locked-phone notification is explicitly a phone checkpoint, not covered by permission-suppressed UI tests. [L5][L6][S2][S11][A4] |
| Audio / haptics | Ticket 13 needs ambient `AVAudioSession`, the rest chime and haptics. No audio/mediaserver/coreaudio/haptic label is in the pinned disable allowlist; local runtime includes `com.apple.audio.systemsoundserver-simd`. | Full slim disables the catalogued store/media labels but does not list the identified system sound/audio labels. Do not additionally disable system sound/audio infrastructure; validate actual AVAudioSession operation rather than keeping a whole category without evidence. Actual phone silent mode, music mixing and physical haptics remain device checks; **unknown:** altered simulator's full dependency path. [L5][L6][S2] |
| SwiftData and settings persistence | App imports SwiftData; ticket 13 uses `@AppStorage`. Full slim disables account/iCloud/keychain-sync services but does not remove app data or preferences; this app's current source uses local SwiftData, not a demonstrated account/CloudKit requirement. | Test save/relaunch behavior through the real app, including `-keep-defaults` when ticket 13 arrives. Do not assume a local-store test validates CloudKit/account-backed behavior; those are deliberately unavailable under full slim. Full dependency equivalence is **unknown**. [L1][L6][S2] |
| Screenshots | Installed `simctl help io` supports `screenshot`; Blocklog captures three appearance/text-size variants. There is no screenshot-related service in the disable allowlist. | Keep rendering, screen geometry, accessibility and appearance unchanged, run all three variants and compare. Screenshot success alone does not prove lock-screen/widgets or other removed features work. [L1][L0][S2] |

`simslim doctor` checks whether selected catalogued services are disabled, **not end-to-end API operation**. Its feature catalog has no XCUITest, keyboard, local-notifications, AVAudioSession or SwiftData check. Use `verify` for profile drift and actual tests/device checks for correctness, rather than invent `--requires keyboard,local-notifications` values. [S11]

### Second profile: pi-jev-device / iPhone 17e

The orchestrator supplied this second session's requirements and UDID; this research did **not** inspect or operate on its repo/device. It uses XCTest/WebDriverAgentRunner, accessibility source/active-element APIs, SpringBoard/home/system alerts/lock/passcode, keyboard predictions and the AutoFill “Passwords” key, CoreLocation/TCC/location resets, Maps and persisted unified logs. It does not need notifications, Siri, Photos, contacts, iCloud sign-in, StoreKit, Health, widgets, Spotlight, Safari or universal-link navigation. [L8]

The proposed **full-slim candidate with two narrow keeps**, for that session to check, is:

```sh
simslim on 1837DED0-2EC6-468C-A464-CC4031477143 \
  --keep com.apple.suggestd,com.apple.swcd
```

No `--except` category is needed. Every category is otherwise disabled. The two keeps have different evidentiary strength:

- **`com.apple.suggestd` (`siri`)** is explicitly described by the tool source as generating “system suggestions and predictions,” and the local iOS 27 plist runs CoreSuggestions' `suggestd`. Keep it for the requested prediction surface, **but the precise dependency of ordinary word predictions/QuickType on suggestd is unknown**: neither the public UIKit API nor the checked source proves it is necessary or sufficient. This is a targeted hypothesis to validate, not a reason to retain all Siri/intelligence services. If the identical prediction bar survives stock-versus-slim without it, drop the keep. [S13][L9][A9]
- **`com.apple.swcd` (`web`)** backs shared web credentials/associated domains as well as universal links. Apple's AutoFill workflow associates domains on install and uses domain credentials in QuickType, so “we don't test links or Safari” does not rule out this dependency for full Password AutoFill. The local AuthenticationServices agent and securityd are not disabled by SimSlim. **Unknown:** whether this session only asserts the generic local “Passwords” button, in which case swcd may be unnecessary, rather than exercises associated-domain suggestions. Keep this individual label for the requested AutoFill surface until the session can distinguish those cases; do not retain all `web`, `icloud` or `pim`. [A9][F3][L9][S2]

This is the one part that cannot honestly be certified from read-only source inspection: **an exact minimal private-daemon graph for keyboard predictions and AutoFill on iOS 27 is unknown**. The proposed two labels preserve the directly implicated catalogued capabilities without whole-category exceptions, but they are not evidence that all predictor/ML/keychain dependencies are intact. The other session must validate the bar and Passwords action, including the ensuing authentication/credential UI, not just that typing still works. [A9][S13][L9]

Precise infrastructure that stays untouched under this command:

| Required function | Source checked | Keep decision |
|---|---|---|
| WDA/XCTest automation, accessibility, home/alerts/lock/passcode | No testmanager/accessibility/SpringBoard/backboard label in disable allowlist; runtime declares accessibility, SpringBoard and backboard services. | No `--keep`: these services are outside the allowlist. Lock/passcode and WDA endpoints must pass actual acceptance, since no complete private dependency graph was checked. [S2][L5][L8] |
| Keyboard and AutoFill UI | Runtime declares `com.apple.TextInput.kbd`, `com.apple.AuthenticationServicesCore.AuthenticationServicesAgent`, `com.apple.securityd`; none is allowlisted. InputUI/KeyboardArbiter are not allowlisted either. | Do not invent invalid keep flags for these. The two targeted allowlisted keeps above address prediction/domain-credential uncertainty, not an iCloud-sign-in requirement. [L9][S2][S10] |
| Location, Maps permission and TCC alerts | Runtime declares `com.apple.locationd`, `com.apple.tccd`, `com.apple.geod`; none is allowlisted. The allowlisted Maps labels are background sync/push/geocorrection/destination/snapshot work. | No broad `apps` exception. Full slim leaves Maps installed and core location/TCC running; permission prompt, map display, location updates and `simctl privacy reset location` acceptance are still required. Whether disabled MapKit SnapshotService is needed by a specific map flow is **unknown**. [L9][S2][L8] |
| Persisted unified logs | Runtime declares `com.apple.logd`, `com.apple.diagnosticd`, `com.apple.logd_helper`, `com.apple.logd_reporter`, `com.apple.syslogd`; none is allowlisted. | No `telemetry` exception. `com.apple.diagnosticextensionsd` is a different allowlisted collector, not `diagnosticd`. Check new messages persist under the device's diagnostics directory and `simctl spawn log`; avoid disabling ReportCrash separately. [L9][S2][S13][L8] |
| Test app and Maps installation/launch | Full slim changes service overrides, not installed app bundles or durable data. | No whole built-in-app category exception solely to leave Maps installed. Run the app-specific flows to detect missing background APIs. [S1][S2][L8] |

**Overlap with Blocklog:** keyboard entry/arbiter, ordinary system alerts, TCC infrastructure and logging are relevant and already outside the disable allowlist for both. Blocklog's checked tests type numeric reps, not password credentials or prediction-bar assertions, so there is **no demonstrated need** to copy either special keep into its profile. If its actual text-field acceptance reveals a prediction dependency, keep only that identified label in Blocklog too. Do not claim accessibility automation requires Siri speech, or local notifications require `apsd`. [L1][L5][L6][S2][A9]

Verification/rollback proposals for both sessions:

```sh
# On already booted devices, after authorized slimming.
simslim measure 92848921-A0FA-4AEF-BD4A-C035637CA6EE
simslim status 92848921-A0FA-4AEF-BD4A-C035637CA6EE
simslim verify 92848921-A0FA-4AEF-BD4A-C035637CA6EE

simslim measure 1837DED0-2EC6-468C-A464-CC4031477143
simslim status 1837DED0-2EC6-468C-A464-CC4031477143
simslim verify 1837DED0-2EC6-468C-A464-CC4031477143 \
  --keep com.apple.suggestd,com.apple.swcd
simslim doctor 1837DED0-2EC6-468C-A464-CC4031477143 --requires universal-links
# doctor uses this feature name to check swcd; it is NOT an AutoFill test.
simslim doctor --list

# Undo per-device managed overrides, including a reboot (not run here).
simslim off 92848921-A0FA-4AEF-BD4A-C035637CA6EE
simslim off 1837DED0-2EC6-468C-A464-CC4031477143
```

For Blocklog, `doctor` cannot certify the required functions because none is represented in its feature catalog. For both, a deliberately removed feature such as `push`, `widgets` or `siri` should report BROKEN; that is expected, not a failed full-slim configuration. `verify` checks the exact configured managed override set; `measure` checks footprint; only the full behavioral suite checks WDA/UI/app validity. Apply nothing to the second session's device without its owner checking the candidate. [S1][S11][L8]

### Other service-trimming ideas

- **Plain wallpaper:** worth a manual experiment on a disposable device before launchd changes if MercuryPoster is crash-looping. Apple Developer Forums thread 805625 has a indexed firsthand report of repeated MercuryPosterExtension crashes on **iOS 26.1**, but full-page retrieval was blocked. Other wallpaper-fix writeups are secondary. **Unknown:** a plain wallpaper stops all poster extensions, quantitative savings, its local iOS 27 behavior, and a supported command to set it. A reported resident process is not itself evidence of a crash loop. [F1][L3]
- **`simctl ui`:** locally exposes only appearance, increase contrast and content size, **not wallpaper, widget disabling, reduced rendering, Siri or Spotlight control**. The CLI supports these listed options on Xcode 27; persistence across boots was not tested. Keep their existing screenshot/test coverage rather than force Reduce Motion or tiny text to save cycles. [L0][L1]
- **`defaults write`:** Apple demonstrates simulator `spawn ... defaults write` for an app's own preferences. That is not documentation of private system preference keys to disable Siri, posters, Photos or Spotlight. No supported current keys were established; **unknown**. Do not cargo-cult domains such as Simulator.app keyboard/window preferences as runtime-service controls. [A2][L0]
- **Kill individual extensions:** parent launchd/XPC jobs may relaunch them; prefer a reversible, explicit source-backed service profile rather than repeated process-name kills. Whether `PosterBoard` removal suppresses every local poster process remains **unknown** until measured. [L4][S4]
- **Smaller/older device/runtime:** iOS 27 locally supports iPhone SE (2nd/3rd generation), mini models and iPhone 17e, but only iOS 27.0 is installed. Apple's Simulator engineers explicitly say device CPU/RAM limits are **not simulated**. A low-end phone type is not a 2 GB RAM cap or a promise of fewer daemons. Smaller screen buffers could help rendering, but savings here are **unknown** and changing device size changes UI coverage/screenshots. Do not downgrade below the app's iOS 27 target to solve host pressure. [L0][A2][L1]

## 2. Simulator and Xcode controls

### Exact local recipe proposals

Use **`-parallel-testing-enabled NO`** in all testing paths, keeping the full list of tests. Specifically add it to `test`, `test-unit`, `test-ui`, `test-one` and the direct `screenshot` test invocation. Do not add it globally to device/build actions merely for consistency. CI already has it. [L1][A1]

```just
# Representative replacement; apply the same flag to the other test recipes.
test: generate
    @just _xcb test -scheme Blocklog -destination "id=$(just _udid)" -parallel-testing-enabled NO {{no_diag}} test
```

Installed Xcode 27 semantics: `-parallel-testing-worker-count 1` spawns exactly one worker **when parallel testing is enabled**; `-maximum-parallel-testing-workers 1` caps workers in that mode. Neither is a needed companion to `-parallel-testing-enabled NO`. `-maximum-concurrent-test-simulator-destinations 1` concerns several explicit destinations; it is not the same thing as the per-target parallel setting. Disabling parallelism changes scheduling and possibly race exposure, not which functional tests are selected; retain purpose-built concurrency checks and a periodic stock gate. Swift Testing's in-process task scheduling is a separate feature, so do not claim the Xcode flag serializes every Swift Testing test function. [A1][A5][A6]

For lower compilation peaks, try **`-jobs 2`**, raise to 3 or 4 only if pressure stays low and build time justifies it. Add **`COMPILER_INDEX_STORE_ENABLE=NO`** to `_xcb` and the direct screenshot build; CI already supplies it. The installed help defines jobs as maximum concurrent build operations; Apple's setting reference defines index emission. This reduces unnecessary build metadata and bounds operation concurrency, **not the compiler's entire process-tree RAM or its internal thread count**. Savings are unmeasured; this is a conservative tuning choice, not an optimal value proven for eight cores. Index-store suppression sacrifices IDE index data, not test assertions. [L1][L0][A7]

```sh
# Placement example, not a command executed by this research.
xcodebuild -project Blocklog.xcodeproj -derivedDataPath build/DerivedData \
  -jobs 2 COMPILER_INDEX_STORE_ENABLE=NO ...
```

Keep **`-collect-test-diagnostics never`**, already present in all test recipes. Apple calls these verbose, long-running diagnostics, such as sysdiagnoses/log archives; Mendoza documents a **600-second** diagnostic timeout and hundreds of MB of artifacts after failures/retries. This cuts failure-tail work, **not normal simulator idle RAM**, and trades away failure evidence rather than functional coverage. Keep `.xcresult`/raw logs and explicitly enable `on-failure` for an isolated infrastructure investigation. Do not disable ReportCrash on the host or simulator. [L1][A1][T1]

### Headless, graphics and caching

**Headless:** do not launch Simulator.app for automated tests or screenshots. `simctl boot`/`bootstatus` and `simctl io screenshot` provide the needed lifecycle/capture APIs; Simulator's separate userspace still runs its OS services. No window is not no rendering, and does not remove posters, SpringBoard or the app. The existing tests already avoid explicit GUI opening, so this is principally a maintained precaution, not the cure for 4 GB of simulator services. **Unknown:** numerical savings or automatic GUI launch behavior on this installed Xcode 27. [L0][L1][A2][S1]

**Graphics:** leave the normal GPU/rendering path and screen geometry alone. Xcode 27 help exposes `simctl io ... screenConfig power on|off` and `geometry`, but their support is not evidence that switching off the screen preserves screenshot, visibility, input or lifecycle tests. Apple's WWDC19 session discusses native Metal acceleration and a separate userspace, not a universal "low CPU simulator" setting. Old rendering `defaults` advice from Xcode 9/iOS 11 is not verified on this runtime. Disabling animations, altering Reduce Motion, resolution, Metal/software renderer, debug instrumentation or all sanitizers changes observable behavior or detection; run those configurations deliberately for their own tests, not silently as resource fixes. [L0][A2][F2]

**Avoid duplicate builds correctly:** Apple documents `build-for-testing` emits built test products, and `test-without-building` runs them. CI already does this and can reuse the build for its bounded retry. For the three screenshot modes, build once with `BlocklogUI`, then replace each loop's `test` action with `test-without-building`, keeping the same scheme, configuration, destination and DerivedData and changing only runtime appearance/text size. Rebuild after any source/test/build-setting change; stale products are invalid evidence. Ordinary repeated `test` with warm DerivedData may already skip most compilation, so the extra saving is **unknown**. Do not split every one-off test merely to add steps. [L1][A1][A3]

**Keep DerivedData warm:** keep the existing stable `build/DerivedData` path, avoid `clean` and deleting module/index/build caches between normal test invocations, and do not let concurrent projects overwrite the same build directory. Apple's incremental-build guidance explains reuse/tracking and profiling. Warm disk caches do not require retaining all IDE/agents/simulators in RAM. **Unknown:** the best compiler cache or DerivedData cache budget for this app; no build timing experiment was performed. [L1][A3]

### Shutdown versus warm boot

Warm **same-device/same-project** batches avoid repeatedly launching its entire userspace and initial migration/indexing work. Cold boots cost time and may contend with test-runner initialization; CircleCI's firsthand experience describes preparation failures from resource contention and recommends preboot. But on this Mac a retained stock simulator occupies substantial memory between steps, so "always leave it booted" is not universally cheaper. [L2][L3][A2][C1]

Recommended policy: **one project holds the heavy-work lock for a short batch** of build/test/screenshot steps, not for unrelated agent thinking. Leave its simulator warm within that batch, then shut down that exact UDID **before releasing the lock** when there is no imminent follow-up or memory pressure is high:

```sh
# Illustrative, after adopting a batch policy; not executed.
~/.pi/agent/bin/sim-lock blocklog "$udid" bash -c '
  trap '\''xcrun simctl shutdown "$1"'\'' EXIT
  mise exec -- just test
' _ "$udid"
```

Do not put cleanup outside the lock where it can race the next owner's use. Do not use `shutdown all`, retain both projects' stock devices, or run unattended idle cleanup during another owner's test. This shell example releases simulator resources at the end of a one-command batch; a real batch would include the successive needed checks before cleanup. **Unknown:** best idle TTL/batch length, cold-vs-warm CPU and RAM after slimming, and whether both projects can safely share a UDID without permissions/app state/WDA collision. Keep dedicated UDIDs initially; optimize the queue's batching rather than force shared test state. [L2][L3][L0][S1]

## 3. Host controls and memory budgets

The existing lock is necessary but insufficient: several agent sessions and non-Xcode jobs share the 8 GB. Admit **one heavy build/test/boot at a time**, and pause optional local model servers, browser-heavy automation, additional compilers and polling agents while that job is active. This is a recommendation based on the supplied memory-pressure evidence, not a measured per-agent budget. Limiting heavy workers treats the source of competition; moving them to a lower CPU priority does not free their working sets. [L2][L3][L7]

Use memory **admission budgets**, not forced memory caps on the simulator/test host. As an initial policy reserve roughly 2 GB for macOS/interactive headroom and make the remaining ~6 GB cover agents + compiler + the one simulator; these numbers are **planning guesses, not measured safe limits**, and RSS totals are unsuitable for enforcing them. Measure actual pressure/footprints and swapout **deltas**, not accumulated lifetime swapouts or retained swap allocation alone. Apple's memory-use guidance and SimSlim's methodology distinguish footprint from simple RSS. [L3][S3][A8]

For genuinely unrelated background jobs, installed `taskpolicy` and `nice` support:

```sh
/usr/bin/taskpolicy -b -c background /path/to/background-job args...
/usr/bin/nice -n 10 /path/to/background-job args...
```

`taskpolicy` changes I/O/scheduling policy and children inherit it; `-c` applies a QoS clamp. `nice` increases the nice value, lowering scheduling priority. These commands do **not** provide a CPU percentage limit or necessarily reduce memory; putting xcodebuild or a simulator under them may delay bootstrap and increase timeout failures. Don't assume Simulator services started by launchd inherit a policy applied only to the xcodebuild client. The installed `taskpolicy` even exposes `-m` MiB limits and resource-exhaustion actions, but do **not** apply those to test processes: killing/throttling/suspending them can create artificial failures rather than a more valid low-memory iPhone simulation. Local syntax is checked on macOS 27; test-side impact is **unknown**. [L7][C1][A2]

A dedicated smaller simulator helps isolation and may reduce pixel/render work, **not** the declared RAM/CPU of the simulated device. Preserve iPhone 17 for canonical visual/UI acceptance; optional smaller-screen coverage is an additional configuration, not an unreviewed replacement. Buying more RAM or moving test execution to a less contended/dedicated host is the next honest capacity option if full slimming and admission limits still leave pressure high; historical runner issue 12777 is evidence that clone preparation failures happen, not proof of this Mac's exact cause. [A2][L0][L3][R1]

## 4. Ranked recommendation for this machine

| Rank | Exact proposal | Expected savings | Test validity / verification |
|---|---|---|---|
| **1** | One heavy-work owner across all projects; pause optional background consumers. Keep the existing lock, batch consecutive same-project steps and shut down its exact UDID inside the lock when done. | Largest immediate containment of thrashing; releases the retained simulator's live workload between batches, but incurs a boot next time. No numeric saving measured. | No tests removed; changes scheduling. Local lock behavior verified; batch policy and optimum warm interval **unknown**. [L2][L3][C1] |
| **2** | Add `-parallel-testing-enabled NO` to every non-CI test and screenshot invocation; CI already has it. | Prevents accidental worker/clone multiplicative load. Savings depend on current scheme execution. | Full functional suite retained, parallel race exposure differs. Flag verified in Xcode 27 help/man; local clone count/run impact **unknown**. [L1][A1][S7] |
| **3** | `simslim on 92848921-A0FA-4AEF-BD4A-C035637CA6EE` with all categories off and no unsupported keeps. | Largest simulator-specific candidate: upstream full slim 4.0 → 0.9 GB; actual iOS 27 unique footprint saving **unknown**. | Reversible but modified system services. Required named infrastructure is outside the pinned allowlist; transitive Blocklog/WDA/keyboard/screenshots/local-notification equivalence **unknown** until compared with stock. [L3][S2][S3][S5][S6] |
| **4** | `_xcb` and direct screenshot builds: `-jobs 2 COMPILER_INDEX_STORE_ENABLE=NO`; retain stable DerivedData. | Lower compile peaks and skip index emission. CI already skips indexing. | Does not drop tests; slower builds possible. Xcode 27 CLI and Apple index setting verified; resource delta **unknown**. [L1][L0][A7] |
| **5** | Keep `{{no_diag}}`; build screenshots once and use `test-without-building` for the three modes. Keep build products warm for retries. | Avoids expensive failure diagnostics and redundant build planning/work. Existing ordinary incremental `test` may already reuse products. | Diagnostics evidence reduced, assertions preserved; never run stale artifacts. Xcode 27 options verified; screenshot restructuring and savings untested. [A1][L1][T1][A3] |
| **6** | Move execution to a bigger/dedicated host if full slimming plus scheduling limits still leaves sustained pressure. | More actual RAM increases capacity; no app-specific host-size benchmark. | Retain the same runtime, full test suite and canonical UI/device coverage. Do not mistake less contention for simulator resource equivalence to an actual phone. [A2][L3] |

The first two changes are the lowest-risk operational fixes; **full SimSlim is the recommended simulator-specific experiment**, as requested, retaining only demonstrated required dependencies. **Do not automatically install anything or replace xcodebuild with mobai-ci, a scheduler daemon or a new test framework to implement this report.** Existing just/xcodebuild/lock plumbing can do the scheduling fixes. [L1][L2][S2][C2]

### Measurement and acceptance plan (not performed)

After approval and a pinned SimSlim installation, on one **disposable** iPhone 17 / iOS 27 device:

```sh
# Read-only on an already booted device; do not use benchmark here,
# because benchmark/profile commands can alter lifecycle/settings.
simslim measure 92848921-A0FA-4AEF-BD4A-C035637CA6EE
simslim top 92848921-A0FA-4AEF-BD4A-C035637CA6EE --json
simslim status 92848921-A0FA-4AEF-BD4A-C035637CA6EE
vm_stat
sysctl vm.swapusage
```

Capture repeated stock samples at matched boot age, both idle and while executing representative tests. Save a baseline full-suite `.xcresult`, timings and light/dark/large-text screenshots. Apply full slimming under the machine lock, repeat the same samples and tests, and compare actual keyboard entry/toolbar behavior, save/relaunch persistence, foreground/background app behavior and image content. Later validate the rest timer's local notifications, audio and permission paths separately, since ticket 13 suppresses permission prompts under UI testing and leaves real alert/chime/haptics to phone checks. Test the other project's WDA flow independently before sharing its profile. [S1][S3][L1][L6]

`simslim measure` reports summed process `phys_footprint`; `status` reports managed disabled labels, **not all process counts**. Record both plus per-process CPU and host pressure: a disabled-label count can look perfect while other XPC extensions remain. Use the same app state and settle interval before/after; inspect trends and swapout deltas over elapsed time, not just one RSS snapshot. Upstream's category experiment used iOS 26.5, a fully slim idle baseline, five baseline samples after 20 seconds and three per-category samples after 15 seconds; those short settles are a method description, **not a prescribed sufficient settle time on this thrashing Mac**. [S1][S3][S8]

On the same device, rollback is `simslim off 92848921-A0FA-4AEF-BD4A-C035637CA6EE` (managed services restored with reboot), followed by the stock tests. Verify after a subsequent reboot that the chosen profile survives and after rollback that it is cleared. Erase is not rollback for useful local app data. Require a stock full suite before canonical review/checkpoint until the slim equivalence experiment is satisfactory, and preserve physical-device checks for actual haptics/silent mode/resource behavior. [S1][S4][L6][A2]

### CI suitability

SimSlim is not local-only: its API/docs explicitly support CI profiles, drift verification and testing-set discovery, and MobAI CI exposes `sim-slim`/`--slim-only`. MobAI CI recommends **widgets only** for CI and supports caching a prepared simulator image, so preparation can be paid once. These are tool-author claims/source capabilities, not our hosted Xcode 27 measurements. Its custom DSL/cache/runner setup is unnecessary to start using a full explicit profile in existing xcodebuild recipes. [S1][C2]

Upstream SimSlim issue #13 reports timeout failures configuring services on GitHub-hosted Macs; fixes include configurable overall/per-spawn timeouts and the offline fast path. Pin a version containing those fixes, fail loudly on configuration failure/drift, and measure setup + tests + cache transfer, not tests alone. The ephemeral hosted job pays setup every time unless compatible prepared-state persistence actually works; don't assume raw Xcode clones inherit a slim base or that slowing the test job down in setup is free. **Unknown:** net CI benefit, runtime-image compatibility and complete Blocklog acceptance on `xcode-27`. [S0][S4][S5][S12][C2][R1]

### Avoid

Avoid additional unallowlisted blanket service disabling, disabling crash reporting, host-system `launchctl unload` advice for simulator bugs, killing Poster processes in a loop, changing signed/shared runtime files, pretending an SE device enforces a small RAM budget, old undocumented `defaults`/software-renderer keys, stopping simulator process trees with SIGSTOP as an unvalidated parking mechanism, and memory caps on xcodebuild/test runners. Avoid silently turning off animations/sanitizers/accessibility coverage or suppressing real failures to compensate for contention. These measures either lack local evidence, remove behavior/diagnostics, or introduce suspension/resource conditions not covered by the tests. [L4][L7][A2][S2][F2]

## Sources and verification ledger

### Local primary evidence

- **[L0] Read-only commands, 2026-10-07:** `xcodebuild -version` → `Xcode 27.0`, `Build version 27A266a`; `xcrun simctl list runtimes -j` → only `iOS 27.0`, build `24A434`, supported architecture `arm64`, runtime path under `/private/var/run/com.apple.security.cryptexd/mnt/com.apple.iPhoneOS.SimulatorRuntime-v24.1.434.0.n9IyuO/...`. Its supported-device inventory includes iPhone 17, 17e, SE and mini models. `xcrun simctl help` exposes lifecycle/spawn/ui/io; `help ui` lists appearance/increase_contrast/content_size only; `help io` lists screenshot, recording and screenConfig power/geometry. `help bootstatus` says it monitors until boot completes and `-b` boots if needed. `xcodebuild -help` says `-jobs NUMBER` is maximum concurrent build operations. No mutating subcommand/build action was run.
- **[L1] Repo primary source:** `justfile:1–184`, `UITests/WorkoutFlowTests.swift:24,53,75–77`, `UITests/ScreenshotTests.swift:27`, `App/BlocklogApp.swift:1` at `c451ddf25225fc55dff307f1125573ea27a8cc78`. Key recipe lines: `_xcb` 47–50; tests 56–70; CI 73–116; run 118–131; screenshot 134–157. Commands: `git rev-parse HEAD` → the cited commit; `git log -3 --oneline -- docs/research justfile` includes `c451ddf CI: boot the simulator before xcodebuild in ci-test`. Earlier research: `docs/research/ci-ui-test-stall.md` and `docs/research/ios-ci-github-actions.md`; claims followed to their owners rather than treated as independent proof.
- **[L2] Machine-local primary source:** `/Users/gvanderclay/.pi/agent/bin/sim-lock:1–35`, read October 7. Header says it leaves its own device booted, code acquires `/tmp/xcode-heavy.lock` via `mkdir`, enumerates default booted devices and shuts down differing UDIDs before executing command. Unversioned local script, not a repo commit.
- **[L3] Task-provided measurement record:** parent session's research brief, October 7, 2026; the load/swap/process numbers above. Not reproduced or causally isolated by this research.
- **[L4] Installed `man launchctl | col -b`:** lines 73–95 describe `bootstrap|bootout` and `enable|disable`; disable says it persists across device boots and prevents loading until enabled. Lines 214–224 say `print` output is not an API. Local host documentation, not an assurance about iOS simulator persistence.
- **[L5] Read-only runtime inspection:** Python `plistlib` reads of `runtimeRoot/System/Library/LaunchDaemons/*.plist` from iOS 27.0 / 24A434 yielded `com.apple.usernotificationsd`, `com.apple.TextInput.kbd`, `com.apple.fullkeyboardaccess`, `com.apple.accessibility.axremoted`, `com.apple.accessibility.axassetsd`, `com.apple.accessibility.axAuditDaemon.deviceservice`, `com.apple.audio.systemsoundserver-simd`, `com.apple.SpringBoard`, `com.apple.backboardd`. A regex inspection of pinned `profiles.go` found no matching keyboard/InputUI/testmanager/accessibility/usernotifications/mediaserver/coreaudio/haptic/BackBoard/SpringBoard labels. This checks declarations and allowlist exclusion, not live state or transitive dependencies. A wider recursive file-name scan was stopped at a 40-second tool timeout and yielded no additional evidence.
- **[L6] Task spec:** `.scratch/blocklog/issues/13-rest-timer.md`, read October 7, untracked/unversioned. Scope names local notifications, ambient AVAudioSession, haptics, user-default persistence and explicitly excludes Live Activities; acceptance criteria reserve notification/chime/music/silent-mode checks for the phone at checkpoint 17. A future spec, not implemented features asserted to exist today.
- **[L8] Task-provided second-session requirements:** orchestrator message October 7, 2026, UDID `1837DED0-2EC6-468C-A464-CC4031477143`; listed WDA/keyboard/Passwords/Maps/location/logging requirements. Not independently reproduced or repo-inspected by this child.
- **[L9] Additional read-only iOS 27.0 / 24A434 plist inspection:** same `plistlib` method as L5, names/programs listed in the second-profile table. `suggestd` program `/System/Library/PrivateFrameworks/CoreSuggestions.framework/suggestd`; `AuthenticationServicesAgent` program `/System/Cryptexes/App/usr/libexec/AuthenticationServicesAgent`; securityd/locationd/tccd/logd/diagnosticd programs in `/usr/libexec/`. Declarations, not live dependency or feature testing.
- **[L7] Installed `man taskpolicy | col -b`:** lines 13–16 I/O/scheduling policy and child inheritance; 32–38 QoS clamp and MiB memory-limit option; 42–46 exhaustion actions; 51–54 Darwin background policy. Installed `man nice | col -b`: lines 9–16 increased nice value lowers scheduling priority. `taskpolicy` man dated December 4, 2025; `nice` man dated February 24, 2011 (older), shipped on macOS 27.0. No policy was applied.

### Apple and first-party tool sources

- **[A1] Installed Xcode 27 `man xcodebuild | col -b`:** lines 280–285 `test-without-building`; 362–395 destination and per-target parallel controls; 433–436 `-collect-test-diagnostics [on-failure|never]` and verbose long-running diagnostics. `xcodebuild -help` independently agrees. A readable **secondary mirror**, not the authority for this check: https://keith.github.io/xcode-man-pages/xcodebuild.1.html .
- **[A2] Apple WWDC19, older:** [Getting the Most Out of Simulator](https://developer.apple.com/videos/play/wwdc2019/418/). Full fetched transcript sections explain separate userspace/launchd, native CPU ABI, device CPU/RAM limits not simulated, native Metal acceleration and `spawn ... defaults write` for app settings. Historical platform explanation, not a benchmark of iOS 27.
- **[A3] Apple:** [Improving the speed of incremental builds](https://developer.apple.com/documentation/xcode/improving-the-speed-of-incremental-builds), retrieved October 7; [TN2339 command-line builds/tests](https://developer.apple.com/library/archive/technotes/tn2339/_index.html), archival/older. Current installed man verifies build/test action semantics.
- **[A4] Apple:** [Scheduling a notification locally from your app](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app), API owner; distinguish local scheduling from SimSlim's push feature map. Local runtime plist and ticket, not an asserted daemon dependency graph, support the proposed guard.
- **[A5] Apple WWDC20, older:** [Get your test results faster](https://developer.apple.com/videos/play/wwdc2020/10221/), fetched transcript discusses parallel/distributed test execution and flags. Optimizes sufficient-resource machines; not a recommendation to parallelize this thrashing host.
- **[A6] Apple Swift Testing:** [Running tests serially or in parallel](https://developer.apple.com/documentation/testing/parallelization), current API documentation, also researched in the repo's earlier CI note. In-process scheduling is distinct from Xcode simulator-worker counts.
- **[A7] Apple:** [Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference), current structured source retrieved via [DocC JSON](https://developer.apple.com/tutorials/data/documentation/xcode/build-settings-reference.json): `COMPILER_INDEX_STORE_ENABLE` → “Control whether the compiler should emit index data while building.” No savings figure supplied by Apple.
- **[A9] Apple Password AutoFill:** [About the workflow](https://developer.apple.com/documentation/security/about-the-password-autofill-workflow), [Enabling AutoFill on a text input view](https://developer.apple.com/documentation/security/enabling-password-autofill-on-a-text-input-view). Structured DocC JSON fetched October 7: the QuickType bar uses saved local passwords/Keychain AutoFill; associated domains supply domain credentials; tapping triggers authentication; app must preserve UI when inactive. No private daemon graph supplied. [Keep up with the keyboard, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10281/) is older public keyboard guidance, not proof of a suggestd dependency.
- **[A8] Apple:** [Gathering information about memory use](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use), source for memory investigation; simulator measurement specifics owned by SimSlim's methodology/source rather than inferred from hardware RAM labels.

### SimSlim (primary implementation and firsthand reports)

All source links below pin `2d4f6361dc6be0eec330f81ecfa558a4abe6f618` (October 4, 2026). Firsthand issue/PR reports are upstream observations, not Apple guarantees; mutable discussion pages checked October 7.

- **[S0]** [Releases](https://github.com/MobAI-App/simslim/releases/tag/v0.11.0), September 24, and [`v0.11.0` source](https://github.com/MobAI-App/simslim/tree/e752a72898ca69f703c74dc79b7b047a4f2093a3). `gh api repos/MobAI-App/simslim/releases` gave v0.11.0 September 24, v0.10.0 September 19, v0.9.0 September 16. Commit API dates main October 4.
- **[S1]** [README](https://github.com/MobAI-App/simslim/blob/2d4f6361dc6be0eec330f81ecfa558a4abe6f618/README.md): measurements, limitations, persistence/rollback, CI, clone, profile and measure/verify/doctor behavior.
- **[S2]** [profiles.go](https://github.com/MobAI-App/simslim/blob/2d4f6361dc6be0eec330f81ecfa558a4abe6f618/profiles.go): exact labels, category downsides, overlap/keep semantics. `widgets`: PosterBoard/chronod/liveactivitiesd only; protected sharingd.
- **[S3]** [Category memory method](https://github.com/MobAI-App/simslim/blob/2d4f6361dc6be0eec330f81ecfa558a4abe6f618/docs/category-memory.md): iOS 26.5 medians/non-additive deltas, baseline 1,113.4 MiB, widget delta 674.7 MiB.
- **[S4]** [slim.go](https://github.com/MobAI-App/simslim/blob/2d4f6361dc6be0eec330f81ecfa558a4abe6f618/slim.go#L22-L233), [simctl.go](https://github.com/MobAI-App/simslim/blob/2d4f6361dc6be0eec330f81ecfa558a4abe6f618/simctl.go#L323-L490): offline/readback/fallback, version check, live disable+bootout, bounded transition pool.
- **[S5]** [PR #18](https://github.com/MobAI-App/simslim/pull/18), firsthand iOS 27 persistent search overrides and raw clone loss (older report).
- **[S6]** [PR #17](https://github.com/MobAI-App/simslim/pull/17), live fleet monitoring / iOS 27 example (older report). Example values are not a controlled stock/slim comparison.
- **[S7]** [PR #9](https://github.com/MobAI-App/simslim/pull/9) and [issue #6](https://github.com/MobAI-App/simslim/issues/6), firsthand testing-set clone discovery (older). Current README/source incorporates fixes.
- **[S8]** [PR #51](https://github.com/MobAI-App/simslim/pull/51), shell batching failure/offline and transition-pool repair; [issue #30](https://github.com/MobAI-App/simslim/issues/30), distinction between overrides, live processes and footprint.
- **[S9]** [PR #7](https://github.com/MobAI-App/simslim/pull/7), share-sheet preservation; [issue #21](https://github.com/MobAI-App/simslim/issues/21) / [v0.6.1](https://github.com/MobAI-App/simslim/releases/tag/v0.6.1), purchase-sheet dependencies (older). Source at the pinned commit includes these repairs.
- **[S10]** [profile_file.go](https://github.com/MobAI-App/simslim/blob/2d4f6361dc6be0eec330f81ecfa558a4abe6f618/profile_file.go#L20-L110): keep/except validation; non-allowlisted keeps rejected.
- **[S11]** [features.go](https://github.com/MobAI-App/simslim/blob/2d4f6361dc6be0eec330f81ecfa558a4abe6f618/features.go): exact doctor feature-to-label mapping and disabled-state test, not API execution.
- **[S13]** [service_descriptions.go](https://github.com/MobAI-App/simslim/blob/2d4f6361dc6be0eec330f81ecfa558a4abe6f618/service_descriptions.go): suggestd system predictions; akd Apple Account tokens; diagnosticextensionsd diagnostic collectors; accessory-related deviceaccessd, not keyboard AutoFill. Tool-author descriptions, not Apple dependency specification.
- **[S12]** [issue #13](https://github.com/MobAI-App/simslim/issues/13), hosted-runner transition timeouts; [PR #15](https://github.com/MobAI-App/simslim/pull/15) and [PR #20](https://github.com/MobAI-App/simslim/pull/20), timeout fixes (older). Current source verified above.

### CI practitioners, runner issues and forums

- **[C1]** Constantin Jacob / CircleCI, firsthand CI-vendor experience, updated October 31, 2025 (**older**): [Xcodebuild exit code 65](https://circleci.com/blog/xcodebuild-exit-code-65-what-it-is-and-how-to-solve-for-ios-and-macos-builds/). Preboot/resource contention advice; not proof of this runtime's internal deadlines.
- **[C2]** [MobAI CI README at `246fcf4`](https://github.com/MobAI-App/mobai-ci/blob/246fcf4ce13e74948f1ad6194dc60d4647fa967f/README.md), checked October 7: `sim-slim` prepared image/profile option and recommended `--slim-only widgets`. [MobAI's firsthand SimSlim article](https://mobai.run/blog/19-ios-simulators-on-a-16gb-mac), July 24, 2026 (**older**), owns its reported 4.0 → 0.9 GB / 19 simulators on 16 GB result; promotional workload example, not Blocklog equivalence evidence.
- **[T1]** Tomas Camin / Subito Mendoza [README at `0d562601110bab102fcb2ad897eeb0aea4155e48`](https://github.com/Subito-it/Mendoza/blob/0d562601110bab102fcb2ad897eeb0aea4155e48/README.md#test-diagnostics-collection), October 6, 2026: diagnostic delay/size and crash-report retention; [service trimming catalog](https://github.com/Subito-it/Mendoza/blob/0d562601110bab102fcb2ad897eeb0aea4155e48/docs/simulator-services.md) independently supports targeted poster/widget grouping. These are the tool author's implementation/experience reports, not Apple's guarantee of a 600-second limit or complete crash retention.
- **[R1]** [actions/runner-images #12777](https://github.com/actions/runner-images/issues/12777), opened August 18, 2025, updated July 13, 2026 (**older**), fetched via GitHub API: missing Clone 1 in XCTestDevices / preparation failures on Xcode 16.4/iOS 18.6. Not an Xcode 27 bug claim or a benchmark.
- **[F1]** [Apple Developer Forums #805625](https://developer.apple.com/forums/thread/805625?page=2), older Xcode 26.1 / iOS 26.1 MercuryPosterExtension crash-loop report. Search-index snippet retrieved; page scrape returned “Security verification ... Invalid connection”. **Incomplete primary-source access**; not independently verified beyond the snippet. [Secondary Codersera workaround article](https://codersera.com/blog/fix-xcode-26-simulator-slow-2026/) dated May 18, 2026 claims setting wallpaper fixes it; no iOS 27 validation. [Forum #806908](https://developer.apple.com/forums/thread/806908) also blocked, so no asserted resolution from that thread.
- **[F3]** [Apple Developer Forums #814156](https://developer.apple.com/forums/thread/814156), indexed firsthand report explicitly implicates swcd in shared-web-credential/domain resolution. Search-index text only; full page not fetched. Apple public [Shared Web Credentials](https://developer.apple.com/documentation/security/shared-web-credentials) owns the capability; exact minimal dependency of the generic Passwords button remains unknown.
- **[F2]** [Apple Developer Forums #83570](https://developer.apple.com/forums/thread/83570), iOS 11/Xcode 9 (**older**); indexed rendering-mode advice, not a source for current keys/efficacy. **Unknown on Xcode 27**, intentionally not copied as a recommendation.

## Unsettled

**Unknown:** this Mac's full-slim footprint and CPU savings; current scheme clone count; complete Xcode 27/WDA/keyboard/local-notification/audio/persistence dependencies; profile persistence and rollback on this exact runtime build; plain-wallpaper effectiveness; current supported resource-saving private preferences; the second profile's exact suggestd/swcd necessity and any other keyboard-prediction/AutoFill dependencies; quantitative headless/smaller-screen/indexing/cache benefits; optimal build jobs/memory headroom/batch duration; and net hosted CI savings. Read-only help verifies the CLI controls, upstream iOS 27 observations establish plausibility, and only the proposed stock-versus-slim acceptance experiment can establish this app's usable safe profile. [L0][S3][S5][S6][L6]
