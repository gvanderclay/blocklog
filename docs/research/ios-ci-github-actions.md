# Fast, small-app iOS CI on GitHub Actions

## Question and short answer

What is the fastest, most efficient current free GitHub Actions setup for building and unit-testing Blocklog, a small native SwiftUI/SwiftData iOS 27 app with Xcode 27 and no third-party Swift packages?

**Recommendation:** Start with one `xcode-27` job, one simulator, the existing pinned mise/just/XcodeGen tools, and one `xcodebuild test` invocation restricted to the unit-test scheme. Use mise-action's built-in tool cache, but no DerivedData, compiler-cache, SwiftPM, or simulator-runtime cache initially. Record timings before adding any build cache. This is a scope-based recommendation, **not a measured claim that this configuration is the fastest for this unpushed app**: Apple recommends measuring first, and a compiler engineer explicitly warns that uploading/restoring the compiler cache can take longer than compilation. [Apple timing guidance][timing] [Compiler engineer, September 2025][cas-forum]

## Date, versions, and evidence limits

Checked **2026-10-07**. Local reconnaissance: `git log -5 --oneline` returned `fatal: your current branch 'main' does not have any commits yet`; the existing `docs/research/tuist-vs-xcodegen.md` contains generator research, not CI timings. The app/toolchain facts in the question are requirements, not a locally tested checkout. `xcodebuild -version` returned `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`. **Unknown:** this app's cold build time, simulator boot time, queue latency, cache size, and successful hosted-test launch with signing disabled. No benchmark was run and no code was changed.

Pinned source snapshots checked:

- runner-images commit `e7c7cb8f4227797c6404a4e98c2ad463c2f70f91`, image **20260928.0222.1**, macOS **27.0 (26A428)**. [Image inventory][image]
- mise-action commit `1ea734b08489cfe55405c1970604c68ad5af563e`; xcbeautify source documentation commit `513e4b12c3f6c965d1d3b66bd5cd9d635f03112d`; actions/cache commit `3edfce9056124e459a23f683a21433670d47daca`; Swift Build source commit `478d0f046178e3b4fb09f5d7256495e73c06f439`. These are research snapshots, **not a recommendation to pin unreleased main commits in CI**. [Mise][mise] [Formatter][beautify] [Cache action][cache-action] [Build settings source][core-spec]
- Apple Xcode **27.0** and **26.0** release notes, live GitHub documentation as retrieved that day. Historical sources older than one month are labeled below; mutable documentation/issue URLs reflect the retrieval date, rather than a pinned release. [Xcode 27 notes][x27] [Xcode 26 notes][x26]

## 1. Runner: use the image already carrying the required platform

The standard `xcode-27` label is an **arm64/M1 runner with 3 CPU cores, 7 GB RAM, and 14 GB SSD storage**, listed as public preview. The image is not available on Intel. GitHub's new support model is one **major** Xcode release per image, not necessarily one installed minor version. [Runner specifications][runners] [GitHub announcement, July 2026][announcement]

The September 28 inventory supersedes the announcement issue's initial beta-3 software table. It lists:

- **Xcode 27.0**, build **27A266a**, default, `/Applications/Xcode_27.app`, with `/Applications/Xcode_27.0.app` and `/Applications/Xcode.app` aliases.
- **Xcode 27.1**, build **27A9269**, stored at `/Applications/Xcode_27.1_beta.app`, with a `/Applications/Xcode_27.1.app` alias.
- **Xcode 27.2 beta**, build **27B5019j**, `/Applications/Xcode_27.2_beta.app`.
- iOS simulator SDKs **27.0, 27.1, 27.2**, but the **installed iOS runtime/device set is 27.0**, with devices including **iPhone 17**, iPhone 17e, iPhone 18 Pro, and iPhone Air. An installed SDK is not evidence of an installed runtime for its version. [Image inventory][image]

For reproducibility, select the already-installed **27.0** alias through `DEVELOPER_DIR=/Applications/Xcode_27.0.app/Contents/Developer`, and log `xcodebuild -version`, `xcrun swift --version`, `xcrun simctl list runtimes`, and the image version at the beginning. **Unknown:** the inventory does not establish the exact Swift compiler version; verify the requested Swift 6.4 on the actual job. The major runner label and its installed software roll forward, so recording versions matters. [Image inventory][image] [Support model][announcement]

**xcbeautify 3.2.1** is documented as preinstalled. **XcodeGen and mise are not documented in the inventory**, and the checked toolset lists xcbeautify but not those tools. Treat XcodeGen/mise availability as **unknown**, rather than relying on undocumented installations; the planned mise bootstrap removes that dependency. Because this project already pins tools, prefer that pin over the runner's formatter version. [Image inventory][image] [Image toolset][toolset] [Mise action][mise]

The preview announcement warns of unstable software and possible queueing while capacity is balanced. **Unknown:** a current median/p95 queue time or typical iOS 27 boot time; the issue's retrieved comments do not provide a benchmark. Older runner reports document real simulator launch/clone regressions on macOS 15/Xcode 16, but are not proof that the September 2026 Xcode 27 image has the same defect. Keep boot bounded and retain diagnostics instead of assuming a fixed sleep solves it. [Preview issue, updated September 2026][preview] [Historical simulator issue, August 2025][boot-issue]

Standard hosted runners are free for public repositories: the **2,000 monthly minutes** in the Free-plan table are not a cap on this public repo's standard-runner minutes. Larger runners remain chargeable even for public repos. GitHub Free has **20 concurrent jobs total, at most 5 macOS jobs**, and hosted jobs have a **6-hour** execution ceiling. These are limits, not reserved preview-image capacity. [Billing][billing] [Limits][limits]

## 2. Caches: what they save, and what is not established

### Mise tools: enable the cache already built into the installer

mise-action defaults to `install: true` and `cache: true`, exports tool paths/environment, and caches the mise data directory, normally `~/.local/share/mise`. Its default cache-key inputs account for platform/image, configuration files, installation arguments, and related settings. Pin the mise binary version deliberately as well as tool versions; leaving it unset can keep an older cached mise until the cache key changes. Do not add a duplicate actions/cache step around mise. [Pinned action README][mise] [Pinned action inputs][mise-inputs]

**Measured payoff for Blocklog: unknown.** This is the first cache to keep because the installer already implements it and it caches reusable tools rather than a large mutable build tree. Verify that the chosen mise backends download release binaries rather than source-compiling XcodeGen/xcbeautify on every miss; the actual project's mise configuration was not available to validate. [Mise behavior][mise]

### DerivedData: possible incremental savings, but not the initial default

Apple's incremental build system tracks input/output changes, and build options affect module reuse. A fresh checkout and freshly regenerated project are not the same filesystem state as the build that produced cached artifacts. The purpose-built `irgaly/xcode-cache` action preserves input **nanosecond-resolution mtimes**, keyed by content hashes, in addition to DerivedData: its own implementation documentation is evidence that a naive directory cache is missing important incremental-build handling, not an Apple guarantee that every target requires this exact action. [Apple incremental-build guidance][timing] [Cache tool author documentation][dd-action]

Absolute-path sensitivity is also real: Swift compiler engineering guidance documents module-cache directory constraints, bridging-header paths, and prefix mapping in Xcode 26. That is compiler-cache evidence, not proof of an identical failure in every DerivedData configuration. Keep checkout, generated project, and DerivedData paths stable if experimenting; invalidate on Xcode **build identifier**, runner architecture/image, SDK, build flags/configuration, and generator/project specification. Generated project and plist input mtimes must be considered too. **Unknown:** which path/mtime pitfalls remain for this pure-Swift Xcode 27 app. [Compiler engineer, August–September 2025][cas-forum] [Generated-input tracking][timing]

A sensible experimental DerivedData key is `dd-v1-<image>-<arch>-<Xcode-build>-<hash(project.yml, mise.toml, justfile, test-plan/config)>-<commit>`, restoring only within that same compatibility prefix. A source hash alone yields mostly cold caches on each code edit; a static key never refreshes after its first save because GitHub caches are immutable. Still run the build/test commands after every restore; a cache hit is not proof that current code was built. This key is a recommendation derived from the input/toolchain constraints, not a tested minimum key. [Immutable caches and restore-prefix semantics][cache-docs] [Compiler constraints][cas-forum]

GitHub removes caches unused for **over 7 days** and defaults to **10 GB total per repository**; that is not a 10 GB allowance for every entry. Increasing the allowance beyond 10 GB incurs charges, contrary to the free-only requirement. New per-commit DerivedData entries can evict useful tool caches; PR-created caches are scoped to the PR merge ref, and the default branch cannot consume them. Cache restore/download, decompression, compression, and upload must all be counted in the comparison. [Cache storage and eviction][cache-policy] [Cache scope][cache-docs]

### Xcode compilation cache: more promising than full DerivedData, still benchmark-gated

Xcode 26 introduced opt-in compilation caching for Swift and C-family builds; Apple says it reuses compilations for the same inputs, especially after clean builds or switching branches. The documented setting is **`COMPILATION_CACHE_ENABLE_CACHING=YES`**; **`COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES`** emits cache-task diagnostics. Xcode 27-era Swift Build source retains these settings. Do not confuse this content-addressed cache with ordinary Build/Products incremental artifacts. [Xcode 26 release notes, older feature introduction][x26] [Current Apple settings reference][settings] [Pinned core settings][core-spec]

A Swift compiler engineer identifies **`~/Library/Developer/Xcode/DerivedData/CompilationCache.noindex`** as the standard cache directory, confirms it can be copied/saved/restored, and explicitly says that copying it is **not the intended use case** and may cost more than compilation. **Unknown:** the effective cache path with this app's custom `-derivedDataPath`, and its Xcode 27 hosted-runner hit rate; verify the actual compiler invocation/cache location rather than assuming it moves with project DerivedData. [Compiler engineer, September 2025][cas-forum]

Cross-machine caching is sensitive to compiler and filesystem paths. Current Swift Build source exposes **`SWIFT_ENABLE_PREFIX_MAPPING`** and **`SWIFT_ENABLE_PROJECT_PREFIX_MAPPING`**, mapping SDK/toolchain and project/build directories to canonical prefixes when compiler caching is enabled. Their existence is verified; **unknown:** whether they alone make restored cache hits reliable for this particular SwiftUI/SwiftData/Swift Testing macro workload. Historical compiler guidance explicitly mentioned macro false negatives. Do not advertise the old Xcode 26 limitations as necessarily unfixed in 27. [Pinned Swift specification, lines 1513–1550][swift-spec] [Historical compiler guidance][cas-forum]

If baseline builds later become expensive, test **only CompilationCache.noindex** before full DerivedData. Use an experimental key `cas-v1-<image>-<arch>-<Xcode-build>-<SDK>-<hash(project.yml, build flags/config)>-<commit>` and restore only within that compatibility prefix, with cache diagnostic remarks enabled for the experiment. Source changes should not invalidate the whole reusable content store, hence the prefix restore. Bound its growth and save only after success. This is a proposed experiment, not a validated Xcode 27 recipe. [Cache immutability/prefix matching][cache-docs] [Cache copying warning][cas-forum]

### SwiftPM and simulator runtime caches: skip them

This app has **no third-party Swift packages**, by task premise. There is no dependency download/build workload to amortize with `SourcePackages`, `.build`, or `~/.swiftpm` caching. Generator dependencies, if any backend source-builds XcodeGen, are tool-installation concerns, not app package caches. The Xcode-cache action itself distinguishes DerivedData from SourcePackages and keys package restoration from `Package.resolved`. [Cache tool's distinction][dd-action]

The iOS **27.0** runtime and appropriate devices are already installed. Do not run `xcodebuild -downloadPlatform iOS`, install Xcode, or cache runtime bundles in this workflow. Selecting OS **27.1/27.2** simply because an SDK is installed would assume a runtime that the image inventory does not promise. [Image simulator/SDK inventory][image]

### What is actually measured?

**No Blocklog-specific cache speedup is measured.** A September 2025 forum participant reported a large, roughly **1,500-Swift-file** macro-heavy app dropping a warm-cache clean build from about **170 seconds to 61 seconds**. This is a **secondary, self-reported measurement**, not a compiler-vendor guarantee, not GitHub Actions, and not comparable to this dependency-free small app. Apple's speedup statements are **vendor feature claims without a representative timing for Blocklog**. The strongest primary recommendation is to measure before caching. [Forum report, post 16][cas-forum] [Apple feature description][x26] [Apple measurement advice][timing]

Evaluate median end-to-end duration over repeated cold and warm runs on the same image/Xcode build: separate queue wait, tool setup, simulator preparation, compilation, test execution, and cache restore/save. Keep a cache only when compilation avoided exceeds restore **plus** save overhead by a useful margin. No evidence supports asserting in advance that every skipped cache costs more than it saves; the decision here is to avoid **unproven** overhead and complexity.

## 3. Build/test structure and flags

**Do not build the app once and then run ordinary `xcodebuild test` as a second independent full task.** Apple documents that `test` builds/runs tests, `build-for-testing` emits products plus an `.xctestrun` description, and `test-without-building` executes already-built tests. For one simulator/one small test bundle, one `test` invocation is the simplest baseline; splitting is not intrinsically a compilation speedup. Use `build-for-testing` then `test-without-building` only when distinct build/test diagnostics, reruns, or destinations justify it, and keep scheme/configuration/paths/destination compatible. [Apple TN2339, archival documentation][test-cli]

Use a shared **unit-only CI scheme/test plan** generated from `project.yml`, so build-for-testing does not build the UI-test bundle accidentally. Apple says build-for-testing builds the scheme's test targets; excluding only UI-test execution is not as clear as excluding it from the CI scheme. The unit bundle's app host makes building that app part of the unit-test dependency graph. Keep local UI tests in the existing local scheme. [Apple scheme/build-for-testing semantics][test-cli] [Dependency graph guidance][timing]

Recommended baseline build settings are **`CODE_SIGNING_ALLOWED=NO`**, **`COMPILER_INDEX_STORE_ENABLE=NO`**, Debug, and the selected simulator destination. Apple's setting reference confirms the index setting controls compiler index emission; this avoids producing IDE navigation data CI does not need, but the seconds saved here are **unknown**. Signing-disabled hosted tests still need a first actual smoke run; do not introduce certificates or `-allowProvisioningUpdates` for a simulator workflow. [Index setting][settings] [Swift index emission condition, lines 1466–1487][swift-spec]

Omit **`-skipMacroValidation`** and **`-skipPackagePluginValidation`**. They are not justified by a project with no downloaded macro/plugin packages; the app's SDK macros are not evidence that dependency trust validation is blocking it. **Unknown:** measurable startup savings from these flags on Xcode 27. They bypass validation rather than supplying a demonstrated optimization; this is a conservative recommendation, not a measured claim.

Pick one concrete available **iPhone 17 / iOS 27.0** device from `xcrun simctl list devices available --json`, obtain its UDID, and pass `-destination 'platform=iOS Simulator,id=<UDID>'`. Do not use `OS=latest`, a hardcoded UDID from another runner, or launch the simulator GUI. The inventory supplies the named device/runtime, and Apple documents destination selection. Starting `simctl boot <UDID>` before compilation and checking `simctl bootstatus <UDID> -b` before execution is an optional overlap optimization: **unknown:** its net benefit and exact behavior on this image, so validate `simctl help` on the first run and bound the wait instead of sleeping a fixed duration. [Available device/runtime][image] [Apple destination syntax][test-cli]

Use one Xcode test worker/device initially; **`-parallel-testing-enabled NO`** is a proposed baseline to avoid simulator cloning, not a proven speedup. Historical runner failures explicitly involve cloned simulators. Swift Testing separately documents default task-group parallelism, generally in one process; it must not be confused with Xcode's multi-device worker parallelism. **Unknown:** the exact interaction of this Xcode 27 CLI flag with in-process Swift Testing scheduling; validate against the selected test-plan settings. Use per-suite `.serialized` only for suites with genuinely shared mutable state, not as a blanket CI speed trick. [Historical clone failure][boot-issue] [Apple Swift Testing parallelization][parallel]

Write **`-resultBundlePath <fresh path>/UnitTests.xcresult`** for the test invocation and retain the raw log. Apple documents that command-line test result bundles contain results and logs and can be opened in Xcode. Add **`-showBuildTimingSummary`** while establishing the baseline. Xcode 27's release notes report delayed stdout/stderr when streaming multiple processes; absence of prompt log output is not by itself a hung test. No Xcode 27-specific speed setting with demonstrated payoff for this app was established. [Results documentation][results] [Timing flag][timing] [Xcode 27 known issue][x27]

## 4. Workflow hygiene and tooling

Use workflow-level concurrency **`ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}`** with **`cancel-in-progress: true`**. This replaces obsolete runs for the same PR/ref rather than consuming scarce preview capacity; include workflow identity to avoid canceling unrelated workflows. Prefer pushes to `main` plus pull requests to avoid duplicate push/PR builds of feature branches, if that satisfies the intended trigger scope. [GitHub concurrency semantics][concurrency]

A **20-minute job timeout** and **5-minute simulator-preparation timeout** are proposed initial guardrails, not measured normal runtimes. GitHub supports job/step timeout settings; adjust from real timings rather than using the 6-hour hosted ceiling. [Workflow syntax][syntax] [Hosted ceiling][limits]

For docs-only skipping, `paths-ignore: ['docs/**', '**/*.md']` on both events works **only when every changed path matches**. Do not exclude project configuration, tool pins, tests, assets, or the workflow. **Important:** a workflow skipped by path filters leaves associated required checks Pending and can block merging. Recommendation: initially keep the required CI check unfiltered; add filtering only if it is not required, or provide an always-running lightweight gate that reports success while conditionally skipping the macOS job. The latter adds another small job, not another workflow. [GitHub path-filter semantics and warning][syntax]

Use **`xcbeautify --renderer github-actions`** for GitHub annotations and readable results, and preserve **`set -o pipefail`** around the pipeline; otherwise the formatter can hide an xcodebuild failure. Optional `tee` preserves raw output. Formatter convenience is worthwhile; **unknown:** any performance gain from formatting. Upload the `.xcresult` and raw log **only on failure**, with short retention (for example 7 days), and tolerate missing files when compilation fails before results exist. actions/upload-artifact supports retention and missing-file handling; current default artifact uploading does not include hidden files unless requested. [Pinned formatter README][beautify] [Upload action][upload]

Use `permissions: contents: read`, ordinary `pull_request`, no signing secrets, and **full commit-SHA pins for actions**, with readable release-version comments and deliberate updates. GitHub identifies a full-length SHA as the immutable pinning mechanism and warns about privileged `pull_request_target` executing untrusted code. Action pins do not freeze the hosted image, hence the Xcode selection/version logs remain necessary. [Security guidance][security] [Image inventory][image]

Purpose-built tooling worth knowing, but not adding now:

- **maxim-lobanov/setup-xcode** selects among **already-installed** Xcodes; its exact-version support is useful for a matrix but redundant with one explicit `DEVELOPER_DIR`. It is not a way to obtain an absent Xcode/runtime. [Pinned setup-xcode README][setup]
- **irgaly/xcode-cache** is a targeted, Tuist-independent DerivedData/mtime/SourcePackages cache action. Consider it only after naive-cache limitations and meaningful compilation cost are demonstrated; it adds filesystem bookkeeping this baseline does not need. [Pinned action README][dd-action]
- **Tuist compilation-cache integration** exists without requiring its project generator, but adds CLI/plugin/service configuration. Its remote-cache claims are vendor claims, not a measured reason to add it to this tiny app. Skip fastlane and alternative hosted runners as workflow orchestration/infrastructure not required by this scope; larger GitHub runners are explicitly paid. **Unknown:** a current free Cirrus/other-provider offer suitable for this repo; do not design around an unverified free allowance. [Tuist vendor documentation][tuist-cache] [Larger-runner billing][billing]

## Recommended concrete workflow design

Create **one workflow and one macOS job**, triggered by pull requests and pushes to `main`, running on `xcode-27`, with `contents: read`, a PR/ref-scoped canceling concurrency group, and a 20-minute timeout. Keep required-check path filters off initially. Check out using a reviewed release's SHA-pinned checkout action; set `DEVELOPER_DIR` to the installed Xcode 27.0 alias and print image, Xcode, Swift, and runtime versions. Invoke SHA-pinned mise-action with an explicit mise version, `install: true`, **`cache: true`**, and its **default cache key**; pinned `mise.toml`/lockfiles own XcodeGen 2.46.0, just, and optionally xcbeautify versions. Do not wrap this cache in another cache action. These choices follow the documented runner/action capabilities, with the timeout and exact tool versions still subject to the first run. [Image][image] [Mise][mise] [Security][security] [Concurrency][concurrency]

Run the existing `just` generation command once. Select the available iPhone 17 on iOS 27.0 by UDID. For the initial simplest version, let one `xcodebuild test` on the generated **unit-only shared scheme** both build the app/test host and execute tests, using Debug, a stable explicit `-derivedDataPath`, that UDID destination, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `-parallel-testing-enabled NO`, `-showBuildTimingSummary`, and a fresh `-resultBundlePath`. Run through `tee` and `xcbeautify --renderer github-actions` with pipefail. No separate ordinary `build` precedes `test`; no package-validation bypasses, clean step, simulator download, or GUI launch is needed. Exact scheme names and the signing/parallelization flags must be smoke-tested on the actual job. [Apple test command][test-cli] [Settings][settings] [Formatter][beautify] [Runtime inventory][image]

If measured simulator startup is material, use the same job/commands but initiate `simctl boot` before a **unit-only `build-for-testing`**, then await bounded `bootstatus` and run **`test-without-building`** with the same settings/destination/DerivedData and its result bundle. That split is justified by overlapping startup or rerunning built tests, not by an imaginary second compilation saving. Upload failure logs and `.xcresult` with short retention; leave UI tests local. [Build/test split][test-cli] [Artifacts][upload]

**Skip initially:** full DerivedData, CompilationCache.noindex, SwiftPM, and simulator-runtime caches. Packages supply no dependency work and the runtime is already present; build-cache net savings are **unknown**, and compiler engineering explicitly warns that persistence may cost more than compilation. Keep only the existing installer's tool cache. If timing later warrants one additional cache, first benchmark a tightly keyed **CompilationCache.noindex** experiment with cache diagnostics and compatibility-prefix restores; retain it only when avoided compilation beats restore/save overhead. Do not claim these build caches universally cost more than they save—there is no app-specific measurement yet. [Runtime inventory][image] [Compiler warning][cas-forum] [GitHub cache behavior][cache-docs]

[image]: https://github.com/actions/runner-images/blob/e7c7cb8f4227797c6404a4e98c2ad463c2f70f91/images/macos/xcode-27-arm64-Readme.md
[toolset]: https://github.com/actions/runner-images/blob/e7c7cb8f4227797c6404a4e98c2ad463c2f70f91/images/macos/toolsets/toolset-xcode-27.json
[preview]: https://github.com/actions/runner-images/issues/14404
[announcement]: https://github.blog/changelog/2026-07-16-xcode-27-runner-image-now-in-public-preview/
[runners]: https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job#standard-github-hosted-runners-for-public-repositories
[billing]: https://docs.github.com/en/billing/concepts/product-billing/github-actions
[limits]: https://docs.github.com/en/actions/reference/limits
[mise]: https://github.com/jdx/mise-action/blob/1ea734b08489cfe55405c1970604c68ad5af563e/README.md
[mise-inputs]: https://github.com/jdx/mise-action/blob/1ea734b08489cfe55405c1970604c68ad5af563e/action.yml
[beautify]: https://github.com/cpisciotta/xcbeautify/blob/513e4b12c3f6c965d1d3b66bd5cd9d635f03112d/README.md
[cache-action]: https://github.com/actions/cache/blob/3edfce9056124e459a23f683a21433670d47daca/README.md
[cache-docs]: https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows
[cache-policy]: https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching#usage-limits-and-eviction-policy
[dd-action]: https://github.com/irgaly/xcode-cache/blob/a17bc58c43fb6414daade43fee49c49d87e807df/README.md
[cas-forum]: https://forums.swift.org/t/about-swift-shared-cache-across-machines/81850
[core-spec]: https://github.com/swiftlang/swift-build/blob/478d0f046178e3b4fb09f5d7256495e73c06f439/Sources/SWBCore/Specs/CoreBuildSystem.xcspec#L1820-L1833
[swift-spec]: https://github.com/swiftlang/swift-build/blob/478d0f046178e3b4fb09f5d7256495e73c06f439/Sources/SWBUniversalPlatform/Specs/Swift.xcspec#L1466-L1550
[settings]: https://developer.apple.com/documentation/xcode/build-settings-reference
[timing]: https://developer.apple.com/documentation/xcode/improving-the-speed-of-incremental-builds
[x26]: https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes
[x27]: https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
[test-cli]: https://developer.apple.com/library/archive/technotes/tn2339/_index.html
[parallel]: https://developer.apple.com/documentation/testing/parallelization
[results]: https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results
[boot-issue]: https://github.com/actions/runner-images/issues/12777
[syntax]: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
[concurrency]: https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency
[security]: https://docs.github.com/en/actions/reference/security/secure-use
[upload]: https://github.com/actions/upload-artifact/blob/cf430e030ddbb5b0abf93d22962f4752f3646cd9/README.md
[setup]: https://github.com/maxim-lobanov/setup-xcode/blob/ed7a3b1fda3918c0306d1b724322adc0b8cc0a90/README.md
[tuist-cache]: https://tuist.dev/en/docs/guides/features/cache/xcode-cache
