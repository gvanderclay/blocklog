# Tuist versus XcodeGen for this personal iOS app

## Question and short answer

Which generator should a single-app, native SwiftUI + SwiftData project use when its owner wants no `pbxproj` editing, no Xcode GUI, and agent-driven command-line builds, tests, and phone installs?

**Recommendation: XcodeGen, pinned to 2.46.0, subject to a first-project smoke test with the actual Xcode 27 toolchain.** Its YAML specification and generation-only CLI fit this scope directly; Tuist's Swift manifests, build/test/run commands, caching, and hosted services provide more capabilities than this app currently needs. Tuist has materially stronger evidence of active Xcode 27 maintenance, so it is the fallback if the actual smoke test exposes a generator compatibility problem rather than a signing or Apple-toolchain problem. This is a scope-based judgment, not a claim that XcodeGen is better maintained. [XcodeGen interface][x-readme] [Tuist interface][t-project] [XcodeGen CI][x-ci] [Tuist CI][t-ci]

## Date, versions, and evidence limits

- Checked **2026-10-07**, initial API snapshot at approximately 14:46 UTC. Local reconnaissance found only `.agents`, no existing research notes, and no Git repository: `ls -la` showed `.agents`; `git status --short` returned `fatal: not a git repository`. No code was changed or tools installed in the app repository.
- XcodeGen stable **2.46.0**, commit `8445e778451c7e44237b90281bde622d764b0084`; also inspected current master activity, ending at `366592bc5be446b427fc8e2a21520344460f96ab`. [Release][x-release] [Current master snapshot][x-master]
- Tuist stable **4.211.0**, commit `0b93604a05fba74ea0d840263d8733c4d3f182df`; installation/licensing documentation also checked at main commit `22243aa84489433e3d585a28279de5926f4ccf93`. Its newest CLI prerelease at the initial check was **4.213.0-canary.8**. [Stable release][t-release] [Canary][t-canary]
- The requested iOS 27 / Xcode 27 / Swift 6.4 / macOS 27 configuration is the task's assumption, not a locally verified environment. `xcodebuild -version` returned `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`. **Unknown:** successful generation, compilation, testing, and free-account provisioning for this exact app on the requested toolchain.
- Pinned releases and some issue reports are older than one month; dates are called out below. An issue report proves someone reported a problem, not that the problem affects every project. Bot-generated issue explanations were not treated as evidence.

## Maintenance health and recent Apple-toolchain compatibility

### XcodeGen

**Active, but slower release cadence and a real compatibility-validation gap for Xcode 27.** Latest stable 2.46.0 was published **2026-07-16**. Earlier releases were 2.45.4 on **2026-04-14**, 2.45.3 on **2026-03-10**, several 2.45.x releases on **2026-03-05**, and 2.44.1 on **2025-07-22**: sporadic releases rather than a weekly train. [Release records][x-releases]

At the check, GitHub search reported **355 open issues and 51 open pull requests**; recent pull-request updates included the Xcode 27 JSON-format proposal on **2026-10-03**, while the latest merged source activity was **2026-09-13**. That September activity includes contributor fixes and maintainer Yonas Kolb's own changes, so “abandoned” is not supported. GitHub contributor totals are dominated by `yonaskolb` (1,312 contributions), with multiple other contributors; that suggests concentrated stewardship, not evidence that only one person maintains it. **Unknown:** staffing, available maintainer hours, succession arrangements, or support commitments. [Issue count query][x-issues-count] [PR count query][x-prs-count] [Recent PRs][x-prs] [Merged activity][x-master] [Contributors][x-contributors]

The 2.46.0 CI matrix explicitly includes **Xcode 16.4 and 26.2**, builds and tests the generator, and generates/builds fixtures. That is positive Xcode 26 evidence, but not blanket support for every Xcode 26 minor release or Xcode 27. Its project serializer dependency is pinned to **XcodeProj 9.14.0**. [CI][x-ci] [Package dependencies][x-package]

Relevant lag and breakage:

- An open **2026-05-12** issue requests Xcode 26's `objectVersion = 100` format. This concerns generating the newer format, not proof that Xcode cannot read older generated projects. [Issue #1620][x-1620]
- An open **2026-09-17** reproduction says Xcode **27.2 beta** rejects a group referenced by two parents when `project.yml` lives inside a module and sources point back to that same directory (`../Module`). The reporter says Xcode 27.0 opens it. A fix is proposed, not released. Keep this app's manifest at the repository root and sources in separate child directories; that avoids the reported shape, although its success here is **unknown until tested**. [Issue #1651][x-1651] [Pending fix #1652][x-1652]
- An open **2026-10-03** PR proposes Xcode 27.2's JSON `project.xcproj` format, updates XcodeProj to 9.17.1, and lists upstream limitations. It is **not a 2.46.0 feature**, and this app does not require switching away from `project.pbxproj`. [PR #1653][x-1653]
- A **2026-09-29** report shows a source-build installation failure resolving XCTest under the **Command Line Tools** developer directory on macOS 27.2/Xcode 27.0. Do not read this as proof that a Homebrew bottle or generated app fails; select full Xcode for source builds. [Issue #1656][x-1656]

**Unknown:** a maintainer-endorsed, fully tested Xcode 27 / Swift 6.4 support statement for the stable release. The absence of a Swift 6.4 search result is not proof of compatibility.

### Tuist

**Very active, with substantially better current Xcode 27 evidence, but a much larger product surface.** Stable releases were **4.208.0 on 2026-09-11**, **4.209.0 on 2026-09-21**, **4.210.0 on 2026-09-28**, and **4.211.0 on 2026-10-05**. Canary releases are more frequent. Be careful with GitHub's generic `releases/latest`: at the initial check it returned a separately versioned Linux-runner-image release, not the CLI release. [4.208.0][t-208] [4.209.0][t-209] [4.210.0][t-210] [4.211.0][t-release] [Release API][t-releases]

At the check, GitHub search reported **188 open issues and 288 open PRs**, with PR activity on **2026-10-07**. Those counts cover the monorepo's CLI, server, runners, and other products; they are not comparable app-generator defect counts. Multiple substantial contributors include `fortmarek`, `pepicrft`, and `esnunes`; the license names **Tuist GmbH**. This is evidence of multiple active maintainers and a commercial organization, not a guarantee of future support. **Unknown:** exact current headcount and contractual support for free CLI users. [Issue count query][t-issues-count] [PR count query][t-prs-count] [Recent PRs][t-prs] [Contributors][t-contributors] [License][t-license]

At 4.211.0, `.xcode-version` is **27.0**, and CLI CI uses **macOS 27.0** runners. A merged **2026-08-27** infrastructure PR added Xcode 27 beta. These are stronger signals than merely allowing a deployment-target string in a manifest. [Toolchain pin][t-xcode] [CI][t-ci] [Infrastructure PR][t-12664]

Recent transition problems demonstrate that Tuist is not immune to Apple changes:

- `tuist run` previously tried to open removed `Simulator.app` on Xcode 27. A fix merged **2026-09-10**, and stable 4.211.0 source includes a DeviceHub fallback. This fix matters if relying on Tuist's run wrapper; using `simctl` directly reduces that coupling. [Report #12740][t-12740] [Merged fix][t-12857] [Stable implementation][t-simulator]
- A **2026-09-04** report of false circular dependencies under Xcode 27 / Swift 6.4 was closed **2026-09-17**. A **2026-10-01** issue about duplicated Swift language-mode flags under Xcode 27 was closed the same day. These are external-package integration cases, not evidence this dependency-free app fails. Closed status alone is not a verified end-to-end result for this app. [#12846][t-12846] [#13752][t-13752]
- An older **2026-06-10** Swift 6.4 decoding report was closed after its author corrected the diagnosis: the trigger was `swift-dependencies` emitting `.treatAllWarnings(as: .error)`, not `swift-collections` as first alleged. Its misleading initial explanation should not be repeated as an established root cause. [Author's correction][t-11203-correction]

## Installation, dependencies, and per-project pinning

### XcodeGen

Official methods include **Homebrew**, **Mint**, building with `make install`, or Swift Package Manager. `brew install xcodegen` uses the Homebrew core formula; at the checked formula commit it has macOS 27 `arm64_golden_gate` bottles, requires Xcode **15.3 or newer for source builds**, and adds no declared external runtime formula dependencies. A source build resolves its Swift-package dependencies, including Yams, SwiftCLI, PathKit, and XcodeProj; those are generator dependencies, not dependencies injected into this app. [Installation][x-readme] [Homebrew formula][x-brew] [Swift dependencies][x-package]

XcodeGen does **not** have a built-in exact project-version installer. `minimumXcodeGenVersion` checks a lower bound, not an exact pin. Homebrew installs a global version. For reproducibility, a `Mintfile` containing `yonaskolb/XcodeGen@2.46.0`, followed by `mint bootstrap` and `mint run xcodegen generate`, pins the tool through Mint; Mint itself is another tool and installs via Swift Package Manager. Alternatively, bootstrap a fixed release binary and verify its version rather than adding a second manager just for one CLI. [Minimum version][x-spec] [Mint pinning][mint]

### Tuist

Official documentation recommends **mise** for per-project pinning: `mise use tuist@4.211.0` writes/uses the project tool configuration, and `mise install` reproduces it. Mise is a separate version manager, not mandatory: Homebrew can install a versioned formula from `tuist/tuist`. [Install docs][t-install]

The checked Homebrew formula downloads a prebuilt release archive and installs **the CLI, `ProjectDescription.framework`, debug symbols, and templates**, with a macOS Monterey minimum and no other declared runtime formula dependencies. It does not install a server or app project dependencies. The CLI package has its own dependency graph, including XcodeProj; using the prebuilt CLI avoids compiling that graph locally. **Important:** use `brew install --formula tuist` or a versioned formula; the same tap also contains a `tuist` **cask for the macOS app**, which is a different product. [Versioned formula][t-brew] [Mac app cask][t-cask] [CLI package][t-package]

## Manifest and editing experience without Xcode

**XcodeGen:** `project.yml` is declarative YAML, with JSON also supported. It covers targets, settings, sources, schemes, and configurations, using defaults and optional templates/includes. An agent can edit it in any text editor and run `xcodegen generate`; there is no manifest-compilation or GUI-edit step. Ordinary editor YAML highlighting works as an editor feature, but **unknown:** a maintained first-party VS Code extension or complete, supported schema-based autocompletion setup. Avoid presenting generic YAML completion as XcodeGen-specific semantic completion. [Format and generation][x-readme] [Specification][x-spec]

**Tuist:** `Project.swift` imports `ProjectDescription`; a root `Tuist.swift` configures tool behavior. Swift gives typed APIs, compiler validation, and reusable helpers. The official first-class completion workflow is `tuist edit`, which generates a separate manifests project and **opens Xcode**. It is recommended, **not required** to author or generate a project: docs explicitly permit any editor. Syntax highlighting outside Xcode is straightforward; **unknown:** a supported turnkey VS Code / SourceKit-LSP configuration that supplies full `ProjectDescription` semantic completion without arranging a build context. Do not claim “Tuist requires the GUI,” or “Swift manifests automatically autocomplete everywhere.” [Editing docs][t-edit] [Manifests][t-manifests]

For this three-target app, my estimate is **roughly 40–65 lines of YAML** versus **roughly 55–85 lines of Swift**, plus a small optional Tuist configuration and either tool's version pin. These are sizing estimates, not measured minimums or validated manifests: both descriptions need three targets, app dependencies from the test bundles, an explicit shared test scheme, iOS deployment target, bundle identifiers, Swift language mode, and signing settings. Either can fit in one primary manifest; no templates, plugins, workspace hierarchy, or manifest helpers are needed for this scope. [XcodeGen target/scheme APIs][x-spec] [Tuist project/target/scheme APIs][t-project]

## Generation and command-line workflow

**XcodeGen** exposes generation, specification dumping, and generation-cache commands; it has **no app build/test/run commands**. Generate once, then use the requested `xcodebuild`, `xcrun simctl`, and `xcrun devicectl` workflows. This is a benefit here: it leaves the agent on the same Apple tooling the user already selected. [CLI command registration][x-cli]

**Tuist** exposes `tuist build` (defaults to `build run`), `tuist test` (defaults to `test run`), and `tuist run` for generated schemes/previews, as well as generation. These are orchestration conveniences, not a replacement compiler/build system; its documented generated-project workflow still uses native Xcode projects and `xcodebuild`. They are optional: `tuist generate --no-open`, followed by native commands, avoids the GUI and keeps build/test behavior under the agent's explicit control. Default `tuist generate` opens its workspace, so remember `--no-open`. [Build command][t-build] [Test command][t-test] [Run command][t-run] [Generation command][t-generate] [Migration build workflow][t-migrate]

Neither tool is evidence that free-account authentication, pairing, certificates, developer mode, or provisioning can be fully bootstrapped without Apple interaction. **Unknown:** an entirely GUI-free first-time free-account setup on this phone; it should be tested separately from generator selection. Generator signing settings are not a workaround for the task's seven-day provisioning constraint. [XcodeGen signing scope][x-faq] [Tuist signing settings][t-signing]

## Required app features

| Feature | XcodeGen | Tuist |
|---|---|---|
| Swift Testing unit tests | Use `type: bundle.unit-test`, with app dependency and a shared test scheme. Swift Testing is a framework used inside the ordinary unit-test bundle, not a special generator product type. [Spec][x-spec] [Apple][apple-tests] | Use `.unitTests`; the same Apple test-bundle rule applies, and Tuist includes generated-project fixtures using `import Testing`. [Product types][t-products] [Fixture][t-testing-fixture] [Apple][apple-tests] |
| XCUITest UI tests | `type: bundle.ui-testing`, app dependency, and inclusion in the test scheme. [Spec][x-spec] | `.uiTests`, app dependency, and explicit scheme test action if desired. [Products][t-products] [Schemes][t-project] |
| Info.plist keys | Inline `info.properties` plus an output `path`, or ordinary build settings/file configuration. Generation writes plist files to disk, so distinguish authored and generated files in Git. [Plist spec][x-spec] | `.default`, `.file`, `.dictionary`, or `.extendingDefault(with:)`; keys can live in Swift rather than the GUI. [InfoPlist API][t-info] |
| Entitlements | Inline `entitlements` properties generate the file and set `CODE_SIGN_ENTITLEMENTS`; a checked-in file can instead be referenced by build settings. [Spec][x-spec] [Usage][x-usage] | Target `entitlements` supports manifest representation; per-configuration files require explicit settings and `entitlements: nil` as documented. [Target API][t-target] |
| Automatic signing and team ID | Set `CODE_SIGN_STYLE: Automatic` and `DEVELOPMENT_TEAM`. There is no special provisioning manager. [FAQ][x-faq] | `.automaticCodeSigning(devTeam:)` sets the same two native build settings, or use a settings dictionary directly. [Implementation][t-signing] |
| Synchronized groups/buildable folders | `type: syncedFolder` or `defaultSourceDirectoryType: syncedFolder`; **`folder` is a different folder-reference concept**. [Source types][x-spec] | Target `buildableFolders`, supported since **4.62.0**; fixtures include asset catalogs in buildable folders. [Best practices][t-best] [Fixture][t-folders] |
| Asset catalogs | Resource file handling includes `.xcassets`; resources belong in the documented `sources` representation, with classification/build phase handling. [Spec][x-spec] [File types implementation][x-filetypes] | Target resources or buildable folders; resource accessor synthesis is another optional layer. [Target][t-target] [Folder fixture][t-folders] [Synthesis docs][t-synthesis] |
| SwiftData | No generator-specific integration expected for local persistence: it is an Apple framework using Swift model macros, available from iOS 17, without external dependencies. **Inference**, not an exact Xcode 27 app test. [Apple framework docs][apple-data] | Same inference; do not add package-generation or caching infrastructure for SwiftData itself. [Apple framework docs][apple-data] |

Signing settings above make the generated project eligible for native automatic signing; `-allowProvisioningUpdates` remains a build-time `xcodebuild` option, not a manifest-level replacement for Apple credentials. **Unknown:** successful seven-day provisioning with this particular team/device. [Signing scope][x-faq] [Native settings implementation][t-signing]

For XcodeGen specifically, the stable base preset defaults **`SWIFT_VERSION` to `5.0`**. Set the app's intended Swift 6 language mode explicitly instead of assuming “newest compiler” changes the default; do not confuse the Swift 6.4 compiler release with the project's language-mode setting. [Stable preset][x-swift-preset]

## Business model, accounts, telemetry, and exit costs

### XcodeGen

The CLI is **MIT-licensed open source**, and the reviewed command registration has no hosted-service/account workflow or paid feature gate. Its own source search for `telemetry`, `analytics`, tracking, and HTTP clients found no telemetry implementation; there is consequently no documented telemetry opt-out to configure. This is a **bounded source observation**, not a network audit of every dependency or of Homebrew/Mint themselves. **Unknown:** independently verified zero network traffic across installation and execution. [License][x-license] [CLI][x-cli] [Source tree][x-source]

Exit is straightforward in principle: generate the `.xcodeproj`, commit it and its shared schemes plus any generated plist/entitlements files, and stop running XcodeGen. The output is a normal Xcode project, and its CLI dependencies are not app dependencies. Continuing to avoid GUI/project-file edits would then require some other generator or accepting manual maintenance; abandoning a generator does not eliminate project configuration work. [Generation contract][x-readme] [Plist generation][x-spec]

### Tuist

The CLI is **MIT-licensed open source and usable locally without a paid plan**. Local generation does not inherently require an account: current `tuist init` defaults to connecting to the server, but supports **`--no-server`**. The broader repository now has multiple licenses, so “all of Tuist is MIT” is incorrect. [License][t-license] [Offline init flag][t-init]

The hosted product has **Air** (free under usage limits), **Pro** (usage-based beyond free thresholds), and **Enterprise** (custom agreements/support/self-hosting offering). Hosted caching, insights, runners, and related connected features have account/service configuration and usage limits; they are not required for generating this dependency-free personal app. Do not rely on old claims that every caching capability is either paid-only or free without limits. **Unknown:** future pricing and the actual bill for a usage pattern not specified here. [Pricing source at 4.211.0][t-pricing] [Connected workflow][t-connected]

**Telemetry/analytics needs careful qualification.** At 4.211.0 the main command wrapper uploads success/failure command events when `fullHandle`, server URL, and its tracking condition are present. `Tuist.fullHandle` defaults to `nil`. Thus an account-connected project can send command/build/test insights, while a local project without a full handle avoids that command-event upload path. Recommended local-only setup: use `init --no-server` or write manifests directly, leave `fullHandle` unset, and do not enable hosted integrations. [Upload conditions][t-track] [Default configuration][t-config] [Init][t-init]

The familiar **`TUIST_CONFIG_STATS_OPT_OUT=1`** variable still has a parser, but a search of **all checked 4.211.0 CLI sources** found `isStatsEnabled` only in the environment protocol, implementation, and mock—**no production caller**. The exact command was `rg -n isStatsEnabled <tuist-4.211.0>/cli/Sources`; output was `TuistEnvironmentTesting/MockEnvironment.swift:34`, `TuistEnvironment/Environment.swift:60`, and `TuistEnvironment/Environment.swift:266` only. It therefore must **not** be advertised as a verified kill switch for current connected-project uploads. **Unknown:** a single current switch disabling every network/analytics path across all Tuist integrations; removing the server connection is the confirmed narrower approach for this app. [Environment implementation][t-env] [Wrapper caller][t-wrapper] [Source snapshot][t-cli-source]

Tuist deliberately keeps the manifest-editing project separate so the generated app project does not depend on Tuist for manifest editing. Leaving can mean committing the last native project/workspace and stopping generation. However, also preserve any referenced synthesized files in **`Derived`**, generated plists, entitlements, and scheme support, or disable unnecessary synthesis first. An account-connected scheme/build workflow needs a separate audit to remove integrations; “commit only the `.xcodeproj` and delete everything else” is not a safe universal recipe. [Editing/exit rationale][t-edit] [Synthesized files][t-synthesis] [Project synthesis default][t-project]

## Gotchas that matter for this particular app

1. **Prefer boring source layout and explicit schemes.** Put the manifest at the root, with `App/`, `Tests/`, and `UITests/` as distinct child directories. Declare one shared app scheme containing both test bundles, so the agent does not accidentally run only one suite. This is a recommendation grounded in the reported malformed-group shape and the tools' scheme APIs, not a proven requirement for every project. [XcodeGen report][x-1651] [XcodeGen schemes][x-spec] [Tuist schemes][t-project]
2. **Use documented resource configuration.** A September XcodeGen issue reports silently missing files under a top-level `resources:` key; the stable target spec documents resources through `sources` and build-phase classification. Treat the report as a reason to use the documented interface, not as proof that every supported resource declaration is broken. Asset-catalog presence should be checked in the initial build/install. [Report #1645][x-1645] [Target sources spec][x-spec]
3. **Icon Composer `.icon` is not `.xcassets`.** An older open XcodeGen issue says `.icon` packages need `options.fileTypes.icon.file: true` to avoid expanding their contents. This matters only if the app adopts Icon Composer; ordinary asset catalogs are already supported. [Report and workaround #1556][x-1556] [Asset file types][x-filetypes]
4. **Synchronized folders reduce regeneration chores, but ordinary groups are the conservative starting point.** Both tools support them; XcodeGen has recent unreleased fixes for synchronized-folder paths and an open multi-platform filter report. Neither feature is necessary to keep a generated project out of Git. For a three-target, single-platform app, always regenerating before the build is a simple acceptable alternative. [Unreleased path fix][x-master] [Filter report][x-1646] [Both tools' APIs][x-spec] [Tuist best practices][t-best]
5. **Tuist's abstraction benefits grow with modules and dependencies.** Its own docs acknowledge that mapping Swift packages into native targets can lag new package features. With no third-party packages, avoid its custom package integration, binary cache, selective testing, and resource-accessor layers unless an actual need appears. This removes unnecessary configuration without denying that those features are valuable for larger projects. [Integration trade-off][t-dependencies] [Synthesis defaults][t-project]
6. **Generation does not replace validation.** There is no successful local Xcode 27 test in this report. Before adopting either tool, generate, run `xcodebuild -list`, build a simulator app, run Swift Testing and UI tests, then build/sign/install on the phone. If those steps fail, classify the error before switching generators; provisioning failures can be independent of generation. [Local toolchain limitation above] [Signing scope][x-faq]

## Final recommendation

**Choose XcodeGen for this app.** Pin **2.46.0**, keep one small root-level `project.yml`, explicitly configure Swift language mode, deployment target, signing settings and a shared test scheme, gitignore the generated project, and keep build/test/install scripts on native Apple commands. This follows the documented capabilities without introducing a second build/test orchestration surface or an account-connected product into a dependency-free three-target project. [XcodeGen specification][x-spec] [CLI scope][x-cli]

**Make the actual Xcode 27 smoke test the acceptance gate, not an afterthought.** Tuist **4.211.0** is the recommended fallback if XcodeGen's stable generator cannot produce a valid project for the simple supported layout: it has demonstrably current Xcode 27 CI and active compatibility fixes. If choosing Tuist instead, pin it with mise, use `--no-server` and `generate --no-open`, and initially keep builds/tests/installs on native tools anyway. Its stronger maintenance signal is the legitimate reason to accept the extra machinery—not imaginary SwiftData or Swift Testing requirements. [XcodeGen CI gap][x-ci] [Tuist toolchain][t-xcode] [Tuist CI][t-ci] [Install][t-install] [Offline init][t-init] [Generation options][t-generate]

## Sources

Release/issue/API links were checked on 2026-10-07; API counts and issue states are mutable snapshots. Code/documentation links are pinned to commits or release tags.

[x-readme]: https://github.com/yonaskolb/XcodeGen/blob/2.46.0/README.md
[x-release]: https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0
[x-releases]: https://api.github.com/repos/yonaskolb/XcodeGen/releases?per_page=10
[x-master]: https://github.com/yonaskolb/XcodeGen/commits/366592bc5be446b427fc8e2a21520344460f96ab/
[x-ci]: https://github.com/yonaskolb/XcodeGen/blob/2.46.0/.github/workflows/ci.yml
[x-package]: https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Package.swift
[x-spec]: https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Docs/ProjectSpec.md
[x-faq]: https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Docs/FAQ.md#how-do-i-setup-code-signing
[x-usage]: https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Docs/Usage.md
[x-cli]: https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Sources/XcodeGenCLI/XcodeGenCLI.swift
[x-license]: https://github.com/yonaskolb/XcodeGen/blob/2.46.0/LICENSE
[x-source]: https://github.com/yonaskolb/XcodeGen/tree/2.46.0/Sources
[x-swift-preset]: https://github.com/yonaskolb/XcodeGen/blob/2.46.0/SettingPresets/base.yml#L49-L50
[x-filetypes]: https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Sources/ProjectSpec/FileType.swift#L73
[x-brew]: https://github.com/Homebrew/homebrew-core/blob/ab63c3fce887d78f66a6a520438fa5014b03a9a2/Formula/x/xcodegen.rb
[x-contributors]: https://api.github.com/repos/yonaskolb/XcodeGen/contributors
[x-issues-count]: https://api.github.com/search/issues?q=repo%3Ayonaskolb%2FXcodeGen+is%3Aissue+is%3Aopen
[x-prs-count]: https://api.github.com/search/issues?q=repo%3Ayonaskolb%2FXcodeGen+is%3Apr+is%3Aopen
[x-prs]: https://api.github.com/repos/yonaskolb/XcodeGen/pulls?state=open&per_page=5&sort=updated&direction=desc
[x-1620]: https://github.com/yonaskolb/XcodeGen/issues/1620
[x-1651]: https://github.com/yonaskolb/XcodeGen/issues/1651
[x-1652]: https://github.com/yonaskolb/XcodeGen/pull/1652
[x-1653]: https://github.com/yonaskolb/XcodeGen/pull/1653
[x-1656]: https://github.com/yonaskolb/XcodeGen/issues/1656
[x-1645]: https://github.com/yonaskolb/XcodeGen/issues/1645
[x-1556]: https://github.com/yonaskolb/XcodeGen/issues/1556
[x-1646]: https://github.com/yonaskolb/XcodeGen/issues/1646
[mint]: https://github.com/yonaskolb/Mint/blob/3ee0f63e6be99cb655a1c567d283aa51a294ffc5/README.md#mintfile
[t-release]: https://github.com/tuist/tuist/releases/tag/4.211.0
[t-208]: https://github.com/tuist/tuist/releases/tag/4.208.0
[t-209]: https://github.com/tuist/tuist/releases/tag/4.209.0
[t-210]: https://github.com/tuist/tuist/releases/tag/4.210.0
[t-canary]: https://github.com/tuist/tuist/releases/tag/4.213.0-canary.8
[t-releases]: https://api.github.com/repos/tuist/tuist/releases
[t-contributors]: https://api.github.com/repos/tuist/tuist/contributors
[t-issues-count]: https://api.github.com/search/issues?q=repo%3Atuist%2Ftuist+is%3Aissue+is%3Aopen
[t-prs-count]: https://api.github.com/search/issues?q=repo%3Atuist%2Ftuist+is%3Apr+is%3Aopen
[t-prs]: https://api.github.com/repos/tuist/tuist/pulls?state=open&per_page=5&sort=updated&direction=desc
[t-license]: https://github.com/tuist/tuist/blob/22243aa84489433e3d585a28279de5926f4ccf93/LICENSE.md
[t-xcode]: https://github.com/tuist/tuist/blob/4.211.0/.xcode-version
[t-ci]: https://github.com/tuist/tuist/blob/4.211.0/.github/workflows/cli.yml
[t-12664]: https://github.com/tuist/tuist/pull/12664
[t-12740]: https://github.com/tuist/tuist/issues/12740
[t-12857]: https://github.com/tuist/tuist/pull/12857
[t-simulator]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/TuistCore/Simulator/SimulatorController.swift#L332-L351
[t-12846]: https://github.com/tuist/tuist/issues/12846
[t-13752]: https://github.com/tuist/tuist/issues/13752
[t-11203-correction]: https://github.com/tuist/tuist/issues/11203#issuecomment-4669184269
[t-install]: https://github.com/tuist/tuist/blob/22243aa84489433e3d585a28279de5926f4ccf93/server/priv/docs/en/guides/install-tuist.md
[t-brew]: https://github.com/tuist/homebrew-tuist/blob/f3f4f151e4d542ac8a27d60190e5a45759d5b787/Formula/tuist%404.211.0.rb
[t-cask]: https://github.com/tuist/homebrew-tuist/blob/f3f4f151e4d542ac8a27d60190e5a45759d5b787/Casks/tuist.rb
[t-package]: https://github.com/tuist/tuist/blob/4.211.0/Package.swift
[t-edit]: https://github.com/tuist/tuist/blob/4.211.0/server/priv/docs/en/guides/features/projects/editing.md
[t-manifests]: https://github.com/tuist/tuist/blob/4.211.0/server/priv/docs/en/guides/features/projects/manifests.md
[t-project]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/ProjectDescription/Project.swift
[t-target]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/ProjectDescription/Target.swift
[t-info]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/ProjectDescription/InfoPlist.swift
[t-products]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/ProjectDescription/Product.swift
[t-signing]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/ProjectDescription/SettingsTransformers.swift#L55-L64
[t-build]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/TuistBuildCommand/BuildCommand.swift
[t-test]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/TuistTestCommand/TestCommand.swift
[t-run]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/TuistRunCommand/Commands/RunCommand.swift
[t-generate]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/TuistGenerateCommand/GenerateRunCommand.swift
[t-migrate]: https://github.com/tuist/tuist/blob/4.211.0/server/priv/docs/en/guides/features/projects/adoption/migrate/xcode-project.md
[t-folders]: https://github.com/tuist/tuist/blob/4.211.0/examples/xcode/generated_ios_app_with_framework_buildable_folders_and_xcassets/Project.swift
[t-best]: https://github.com/tuist/tuist/blob/4.211.0/server/priv/docs/en/guides/features/projects/best-practices.md
[t-testing-fixture]: https://github.com/tuist/tuist/blob/4.211.0/examples/xcode/generated_app_with_signed_local_binary_swift_package/App/Tests/AppTests.swift
[t-synthesis]: https://github.com/tuist/tuist/blob/4.211.0/server/priv/docs/en/guides/features/projects/synthesized-files.md
[t-dependencies]: https://github.com/tuist/tuist/blob/4.211.0/server/priv/docs/en/guides/features/projects/dependencies.md
[t-init]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/TuistInitCommand/InitCommand.swift#L47-L115
[t-pricing]: https://github.com/tuist/tuist/blob/4.211.0/server/lib/tuist_web/marketing/controllers/marketing_html/pricing.html.heex
[t-connected]: https://github.com/tuist/tuist/blob/4.211.0/server/priv/docs/en/guides/get-started/generated-xcode-project.md
[t-track]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/TuistKit/Commands/TrackableCommand/TrackableCommand.swift#L83-L141
[t-config]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/ProjectDescription/Tuist.swift#L197-L207
[t-env]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/TuistEnvironment/Environment.swift#L266-L273
[t-wrapper]: https://github.com/tuist/tuist/blob/4.211.0/cli/Sources/tuist/TuistCommand.swift#L188-L202
[t-cli-source]: https://github.com/tuist/tuist/tree/4.211.0/cli/Sources
[apple-tests]: https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project
[apple-data]: https://developer.apple.com/documentation/swiftdata
