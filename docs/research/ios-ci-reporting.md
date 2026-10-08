# How can Blocklog make iOS CI failures readable without downloading artifacts?

## Short answer

**Keep the existing native `xcresulttool` + small Python reporter, rather than replacing it with a reporting service.** The highest-value additions are: make its report visible to **`gh run view --log-failed`**, separate and bound reporting from simulator collection, emit source-located workflow annotations, and explicitly report missing results, zero-test infrastructure failures and passed-on-retry tests. Add a JUnit publisher only if a separate test check becomes useful; prefer `mikepenz/action-junit-report` for that experiment. Screenshots and videos need an actual web-hosting decision, not merely an artifact upload. These are recommendations based on the capabilities and local gaps below, not changes applied by this research. [G1][G3][L1][L2][M1][A1]

## Date, versions, and evidence limits

Checked **2026-10-07**. Local repository HEAD: **`c451ddf25225fc55dff307f1125573ea27a8cc78`**. The workflow, recipes, reporter and stall note were **uncommitted working-tree material**, read as supplied; they are not attributed to the committed baseline. Installed Apple tools report **Xcode 27.0 / 27A266a**; the prior local stall research checked **xcbeautify 3.2.1**. Upstream action/tool and app sources are pinned to the commits in the evidence index, not assumed to be released versions. [L1][L2][A1]

GitHub/Apple documentation is live documentation checked on this date, with no immutable documentation version available here. Historical posts are explicitly dated below; they are older than one month. Current app/tool source snapshots were checked rather than copying historical blog YAML. **Unknown:** actual successful execution of any proposed third-party action on Blocklog's Xcode 27 runner. No hosted run, test mutation, production workflow change, or commit was made.

## 1. What the current setup already gets right, and what it misses

The working-tree `.github/workflows/ci.yml` already has separate unit/UI jobs, a 20-minute job limit, a 16-minute test-step limit, pinned checkout/mise/upload actions, version printing, failure/cancellation collection, and seven-day failure-artifact retention. `justfile:71–123` uses `pipefail`, raw `tee` logs, `NSUnbufferedIO=YES`, GitHub renderer output, a bounded preboot, fresh result paths and a narrowly scoped outer preparation retry. Those are existing features, **not new recommendations**. [L1]

The current reporter uses the **modern** `get test-results summary` API and exports diagnostics. It prints assertion texts, existing crash symbols and raw-log tails, then appends the same text to `$GITHUB_STEP_SUMMARY`. Important gaps in this actual working-tree implementation are: [L2]

- **`--log-failed` is not the same as “all useful logs from a failed job.”** GitHub CLI selects failed **steps**. The reporter is in a later successful collection step (`python ... || true`), so its output is not selected by that command merely because the test step failed. The job summary remains visible in the browser, and full `--log` includes the reporting step. This is a direct consequence of the documented CLI selection and the workflow, not a tested hosted CLI result. [G3][L1]
- **Slow collection can prevent the report being written.** Simulator `log show` runs before Python, without its own bound, sharing one step; only afterwards is the artifact uploaded. Split short report generation from potentially expensive collection. The existing four-minute job/step gap is valuable but includes setup, collection and upload, rather than guaranteeing four free minutes. [L1][G2]
- **Phase messages are not in the saved xcodebuild log.** `say()` writes to stdout outside the `tee` pipelines; the reporter searches saved `.log` files for those lines, so it cannot recover those recipe markers from those files. Persist phase/status information separately or tee `say()` into the raw log. [L1][L2]
- **Parse errors are hidden.** `xcr()` discards nonzero exit status and stderr into `{}`; unavailable/malformed bundles become “unreadable”/`None` without the reason. A build failure with no `.xcresult` produces only a log tail. A bounded, explicit “no test session/result bundle” section is more useful than implying no test failures means success. [L2]
- **The report is one giant fenced block.** Its apparent Markdown headings are literal text; use a short real Markdown diagnosis/count section, then bounded `<details>` and code blocks for stacks/tails. The current stack printer reports symbols present in `.ips`; it does **not** symbolicate unsymbolicated addresses. [L2][G1][A3]
- **Passed-on-retry assertions are not deliberately surfaced.** The workflow condition recognizes an outer `*-retry.xcresult`, but not every internal `-retry-tests-on-failure` recovery. Result repetitions must be inspected independently of the final verdict. [L1][L2][A1][P1]

## 2. GitHub-native reporting features and general actions

### Three output surfaces, three jobs

1. **Live job log:** print a short diagnosis and failures; use `::group::` for lengthy supporting evidence. The log is the surface `gh run view --log` reads. `--log-failed` only reads failed steps, so publish a compact report there too. [G1][G3]
2. **Job summary:** append GitHub-flavored Markdown to `$GITHUB_STEP_SUMMARY`. This needs no Checks API token, is grouped on the run's summary page, and supports links/images whose URLs are actually browser-accessible. Each step has a **1 MiB** summary limit; only **20 step summaries** are displayed per job. Limit output rather than pouring all simulator logs into it. Summary upload errors do not themselves fail the job. [G1]
3. **Annotations / PR check:** `::error file=Tests/FooTests.swift,line=42,title=Test failure::message` and `::warning::message` use the runner's workflow-command machinery. Normalize paths relative to the checkout, only attach lines actually present in the result, and use a fileless annotation for launch/preparation failures. Do not guess a file from a test-class name, especially for Swift Testing. A separate check run instead uses the Checks API and needs `checks: write`; PR comments are another permission/surface, not a requirement for ordinary workflow annotations. [G1][G5][M1]

Escape workflow-command message data (`%`, CR, LF) and property values (also colon/comma), or use an action toolkit that does so. Treat result text as data, not raw shell or raw workflow commands; use normal HTML/Markdown escaping when composing summaries. The official toolkit supplies escaping and problem-matcher behavior. [G1][G4]

**Problem matchers** register regex patterns with `::add-matcher::` and map logged file/line/message groups into annotations. They are useful for tools that only print structured text. Blocklog's xcbeautify renderer already emits GitHub workflow commands, so an overlapping xcodebuild matcher would duplicate annotations and add another regex implementation. Prefer one producer of each annotation category. [G4][B1]

**Checks API limits are not the same as action-specific limits.** GitHub accepts at most **50 annotations per API request**; clients can append annotations in further updates. The older xcresult action caps its own report at 50 annotations, whereas mikepenz exposes `update_check` for more than 50. This project needs a few actionable failures, not hundreds of repeated annotation copies. [G5][K1][M1]

### General test-report actions compared

| Tool | Actual input/output | Fit and cost for Blocklog |
| --- | --- | --- |
| **mikepenz/action-junit-report** | JUnit XML; check runs, annotations, job/detail/flaky summaries, optional PR comments; `annotate_only: true` supports read-only/fork contexts. `require_tests` detects missing tests. | **Best optional publisher.** A Node action plus XML generation; no Ruby or reporting account. Existing `contents: read` does not authorize check creation; either use annotation-only or grant job-scoped `checks: write` on trusted runs. XML source-path fidelity and retry semantics still need verification. [M1] |
| **dorny/test-reporter** | Multiple specific formats, including experimental `swift-xunit`, rather than an xcresult reader; creates checks, annotations and Actions summaries. | Good general action, but no direct xcresult advantage. Swift/JUnit adapter compatibility and source mapping need a fixture before adopting. Its documented fork workaround is a separate `workflow_run` publication workflow. [D1] |
| **EnricoMi/publish-unit-test-result-action** | JUnit/NUnit/TRX; job summary, check summary, annotations, optional PR comments and comparison with earlier results. | Richer than needed. On macOS use the `/macos` non-Docker variant, which sets up its Python environment/dependencies; this is not a stdlib-only inline Python script. Check/PR publication needs permissions and fork setup. Useful if history/comparison becomes necessary. [E1] |

None of these actions directly turns a simulator boot failure with no executed tests into a truthful XCTest report. Keep infrastructure reporting alongside test XML; do not manufacture “all tests passed” from an empty document. A JUnit publisher also does not make all its own successful-step output appear in `--log-failed`. [D1][M1][E1][G3]

For forks, keep build/test execution unprivileged. If later implementing `workflow_run`, the privileged publisher should parse artifacts as untrusted data, not check out/execute a contributor's scripts. **Do not switch the test workflow to `pull_request_target` to get a writable token.** GitHub explicitly warns about untrusted code with this event. Ordinary summaries/workflow annotations avoid this additional workflow today. [G6][M1][D1][E1]

### Timeouts, artifacts, CLI, and debug logging

- **Step-level `timeout-minutes`:** keep a test bound below the job bound, and independently bound simulator collection and reporting. A job's maximum time still includes setup and later steps. `always()` can run after cancellation but is not a guarantee against runner loss, forced termination or job timeout; GitHub cautions against indiscriminate `always()` and recommends `!cancelled()` where appropriate. Cancellation cleanup is best-effort. [G2][G7]
- **Artifact retention:** seven days is a sensible existing choice for a personal project, rather than the action's default 90 days. `artifact-url` can link the archive in the summary, but the user must be logged in and it expires with retention; it is a **download link**, not an inline screenshot URL or HTML-report host. `compression-level: 0` can reduce CPU for already-compressed videos/logs at a storage cost; measure before changing it for xcresult contents. Missing-result artifacts should not replace the primary failure message. [U1]
- **CLI incident path:** `gh run view RUN --log-failed` for short failed-step output; `gh run view RUN --log --job JOB` to include successful reporting; `gh run view RUN --json jobs` for job IDs; `gh run rerun RUN --failed --debug` for a debug rerun. The CLI documents fallback limitations when job/step logs cannot be associated (including `UNKNOWN STEP`, and failure if over 25 job logs need the fallback). Blocklog's two jobs are far below that latter limit. [G3][G8]
- **Debug logging:** `ACTIONS_STEP_DEBUG=true` increases runner/action step debug events, and `ACTIONS_RUNNER_DEBUG=true` creates extra runner diagnostic files in the downloadable log archive. These do **not** turn on app/test instrumentation or recover missing simulator output. Use a one-off debug rerun before setting noisy persistent variables. [G8][G9]

## 3. iOS tools, attachments, diagnostics, and Xcode compatibility

### Prefer the installed modern Apple interface

Apple introduced streamlined xcresult extraction interfaces in **Xcode 16** (older release notes). On installed **Xcode 27**, `xcresulttool help get object` still documents a deprecated legacy interface requiring `--legacy`; it says this will be removed in a future release. Modern `get test-results` exposes `summary`, `tests`, `test-details`, `activities`, `insights`, and `metrics`. The old `get --format json` object graph and the modern JSON are not interchangeable shapes. [A1][A2]

The current summary schema gives `testFailures` with `failureText` and stable string/URL identifiers, not a standalone file/line field in each failure. Fetch **`test-details --test-id ...`** and inspect its nested `TestNode.sourceLocation` (`filePath`, `lineNumber`) and failure/source-reference nodes for source-located annotations and repetitions. Do not parse the first `File.swift:42` substring as the only truth. Installed command `--schema` output lets a small parser validate assumptions without adding packages. [A1]

Native attachment export is already available:

```sh
xcrun xcresulttool export attachments \
  --path build/results/BlocklogUI.xcresult \
  --output-path build/attachments/BlocklogUI --only-failures
```

Xcode 27's help documents `--test-id`, filename `--filter`, `--only-failures`, and a `manifest.json` describing each test's attachments. It exports attachments that exist; it does not create a recording after a test runner failed to start. `get test-results activities` supplies activity trees for all runs of a repeated test. [A1]

### Tool/action inventory

| Tool | What it adds | API/compatibility and decision |
| --- | --- | --- |
| **xcbeautify** | Already-installed log formatting, GitHub workflow annotations, and JUnit generation (`--report junit --report-path ... --junit-report-filename ...`). | Its XML is built from recognized streamed log events, **not the xcresult database**. Thus it avoids the legacy API migration but can lose information absent from the log or truncated on timeout. Use it for cheap optional XML, not as the sole source of crash/retry evidence. Separate filenames per scheme/invocation avoid overwriting reports during the build/test split or outer retry. [B1][B2] |
| **kishikawakatsumi/xcresulttool** | GitHub Checks with failures, activities, coverage and saved screenshots; macOS-only. | Pinned parser invokes old `get --format json` and old export without `--legacy`. That is a concrete mismatch with Xcode 27's documented requirements. **Skip this snapshot.** Furthermore, attachment code POSTs image bytes to `xcresulttool-file.herokuapp.com`; do not confuse that with GitHub-native attachment hosting. Service availability/privacy behavior is **unknown**. [K1][K2][K3][A1] |
| **slidoapp/xcresulttool** | Fork of that Checks action. | Pinned parser adds `--legacy` for Xcode >=16 in get/export. This is a compatibility bridge, **not** migration to `get test-results`. Its attachment implementation differs from upstream, so screenshot claims inherited in its README need actual run verification. Xcode 27 execution and long-term legacy availability are **unknown**. Skip in favor of the native reporter. [S1][S2][A1] |
| **a7ex/xcresultparser** | Native Swift CLI; text, GitHub-safe Markdown, HTML, JUnit and coverage outputs, explicit flaky/expected-failure semantics. | Current source calls modern `get test-results`; this is the strongest small-tool fallback if our own result formatting grows. `xcresultparser -o github -f RESULT.xcresult` can feed a summary. **Important:** its documented JUnit flaky cases still count as failures, with `flaky="true"` and `[FLAKY]`; choose publisher policy deliberately rather than changing CI verdict accidentally. Install/pin one extra CLI; tested Blocklog Xcode 27 compatibility remains **unknown**. [P1][P2] |
| **XCTestHTMLReport** | Detailed browsable HTML with screenshots, video, activities and mixed-result filtering; inline single-file output; optional JUnit/JSON. | Current README describes version-4 modern and legacy readers, default `auto` preferring legacy while available. `--result-reader modern` avoids that dependency. This is current source, not confirmation that the package manager's stable release contains it. Excellent for a later hosted report, **not** natively rendered by uploading an HTML artifact. [H1] |
| **trainer / fastlane scan** | trainer converts results to JUnit; scan orchestrates testing, formatters, logs and result bundles. | Current trainer selects modern parser for supported `xcresulttool` versions unless forced legacy, and its modern parser invokes `get test-results tests`. scan offers JUnit/HTML output configuration and retry/result-bundle options. Sound if already using fastlane; Blocklog would add Ruby/Bundler and replace or duplicate its working just recipes merely for reporting. **Skip now.** [F1][F2][F3] |

### Screenshots and videos: separate capture from publication

Failure screenshots/recordings in `.xcresult` are useful evidence; Al Wold demonstrates both in Xcode, including a CI time-zone mismatch invisible in the terse console verdict (February 2024, older firsthand experience). XCTestHTMLReport can render PNG/JPEG/HEIC/video and convert HEIC for browsers. Native export avoids adding a converter for simple PNG capture. [W1][H1][A1]

A runner-local `![failure](build/attachments/UUID.png)` in the summary has no corresponding browser-served file. An upload-artifact archive URL downloads the archive rather than serving its internal files. **To satisfy truly no-download visual reporting**, publish only selected attachments/report files to a browser-accessible host (for example a dedicated GitHub Pages reporting deployment), and link/embed those URLs. That is a new retention/privacy/security task: artifacts may contain app data and should not be made public by default. The HTML tool's own Pages-hosted live report demonstrates the hosting distinction. Do not deploy arbitrary PR-produced HTML under a trusted origin without reviewing its content and escaping; screenshot-only publication has a smaller surface. **Unknown:** no end-to-end image/video publication path was verified for this repo. [G1][U1][H1][K3]

Recommendation for now: print attachment counts/test associations and retain the bundle; add native failed-attachment export when visual assertion debugging actually needs it. Do not introduce continuous `simctl recordVideo` for every run while automatic result attachments may already suffice. **Unknown:** which automatic videos/screenshots survive Blocklog's exact test-plan settings, failure modes and `-collect-test-diagnostics never`; check a deliberately failed result bundle before promising them. [A1][L1]

### Simulator logs and crash symbolication

Keep targeted simulator logs as supporting evidence, not the entire 20-minute unified log in the summary. Existing collection gathers a gzip log and `.ips` files; the reporter never reads that gzip, and it only selects crash reports from diagnostic exports rather than app/test stdout files. Add a bounded shortlist from exported `StandardOutputAndStandardError*.txt` and simulator output for relevant processes and the last failing phase; quote it under `<details>`. Wold demonstrates app/test stdout files inside xcresult diagnostic exports, but their exact paths and retention are older observations and **unknown on this Xcode 27 failure configuration**. [L1][L2][W1][A1]

Distinguish app assertion/crash from test-runner crash, preparation failure, timeout/cancellation and reporter failure. A crash stack in `XCTWaiter` alone does not establish the root cause; the earlier local research explicitly leaves that diagnosis unknown. Print process, timestamp, exception/termination, triggered thread and relevant existing symbols, with “partially/unsymbolicated” when appropriate. Do not describe address offsets as symbolication. [L2][L3][A3]

Apple's current symbolication docs support **`xcrun crashlog`**, **`CrashSymbolicator.py`** (JSON `.ips`, `-d` matching dSYM, optional output file), and **`atos`** with architecture/load address and the correct image. Keep the original crash plus the matching binary/debug symbols before runner teardown if our app frames are missing; do not assume the framework/test-runner dSYM is ours. Prefer Apple's shipped script to implementing a JSON symbolicator. **Unknown:** availability of matching Blocklog simulator/test-host dSYMs under current Debug build settings, and fully unattended behavior of `crashlog`. No symbolication was executed. [A3]

## 4. What real open-source apps and practitioners do

The following are **source observations at pinned current commits**, not proof of green runs or an industry-wide survey. Four directly useful app examples were found; inspecting additional repos stopped when they added no reporting technique. [O1–O8]

| App / source | Concrete pattern observed | Lesson for us |
| --- | --- | --- |
| **NetNewsWire**, `ci.yml` | iOS and macOS xcodebuild logs via `tee` + `xcbeautify --renderer github-actions`; fixed result bundle paths; xcresult uploads. | Our live-log/annotation baseline matches a maintained native app; artifact upload alone does not answer the no-download diagnosis requirement. [O1] |
| **Wikipedia iOS**, `run_ui_tests.yml`, `run_unit_tests.yml` | Separate simulator preparation, explicit destinations/results, `xcpretty`, preserved xcodebuild pipeline status, `always()` result uploads for UI; local coverage-summary action. | Explicit preparation and results recur; do not copy its formatter/dependency choice merely because it is bigger. Its coverage summary is not an all-failure diagnosis. [O2][O3] |
| **Element X iOS**, `ui-tests.yml`, `compound-ios.yml` | Xcode 27 runner; Swift tooling produces zipped xcresult + JUnit/Cobertura; failure artifacts retained seven days; Codecov test results on non-cancelled/trusted contexts. Compound tests use xcbeautify GitHub renderer. | Good evidence the preview generation is used elsewhere, **not** proof all our candidate parsers work. Service integration adds credentials/external destination; our immediate need is GitHub-native. [O4][O5] |
| **DuckDuckGo Apple browsers**, iOS `ios_ui_tests.yml`; macOS `macos_pr_checks.yml` and local `process-test-results` action | iOS saves result bundle and uploads it. The same maintained app's richer **macOS**, not iOS, workflow tees logs, emits xcbeautify JUnit, uses per-test time allowances/retries, injects xcresult crash evidence into XML, creates a summary, then publishes mikepenz checks and crash artifacts. | Most relevant incremental pattern: **enrich a concise report with crash evidence rather than install another entire CI framework**. Clearly distinguish macOS evidence from iOS evidence. [O6][O7][O8] |

Additional inspection: Ice Cubes' downloaded workflows added no distinct test-reporting example; inspected Mastodon and Signal workflows likewise did not supply a better relevant test-report pattern. Kickstarter's repository tree at the checked commit supplied no `.github/workflows` files. This is a statement about the inspected tree, **not proof that these apps do not test or use another CI provider**. [O9]

**Recurring patterns:** explicit result paths; raw-log preservation plus a formatter; post-failure result retention; separate simulator/setup or build/test phases; JUnit/check publishing where teams want richer test navigation; retries with explicit limits. No observed pattern establishes that an HTML artifact renders automatically in GitHub or that retries fix runner preparation. These are qualitative observations from the cited workflows, not measured frequency claims. [O1–O8]

### Practitioner reports (older; not API authority)

- **Al Wold, February 7, 2024:** firsthand GitHub Actions recipe and failing snapshot/UI demonstration; shows why result screenshots, videos and app/test stdout reveal things terse failure lists omit. His artifact-download approach is valuable evidence but explicitly does **not** meet the current no-download goal. [W1]
- **Antoine van der Lee / SwiftLee, June 22, 2021:** firsthand flaky-test guidance; distinguish race conditions, environmental assumptions/global state and external services; use bounded test repetitions to collect evidence and reproduce, not dismiss a CI failure because it passes locally. This is not a modern Actions workflow tutorial, nor proof of Xcode 27 compatibility. [W2]
- **Constantin Jacob / CircleCI, updated October 31, 2025:** CI-vendor practitioner explanation of exit code 65 and simulator/preboot timing; useful rationale for phase visibility and early boot, but not proof of the cause of this GitHub runner's crash. The existing local stall report already investigated this failure class, so no new speculative simulator settings are proposed here. [W3][L3]

## 5. Ranked adoption plan

### 1. Make the existing report reachable from every requested surface

**Change:** `.github/workflows/ci.yml` names/IDs the test step (`id: tests`), runs a short **separate** bounded `Report CI failure` step before slow collection, passes the test outcome to the reporter, and gives it a failure exit **only when the original test step failed**. This makes its printed diagnosis part of a failed step selected by `--log-failed`. On an outer-retry recovery, keep the reporting step successful and emit warnings; on cancellation, report best-effort without inventing a test assertion. Do not `continue-on-error` the test invocation. [G3][G2][L1]

Illustrative workflow shape (proposal, not executable replacement for the full workflow):

```yaml
- name: Build and test
  id: tests
  run: just ci-test BlocklogUI
  timeout-minutes: 16
- name: Report CI failure
  if: failure() || cancelled() || hashFiles('build/results/BlocklogUI-retry.xcresult/Info.plist') != ''
  timeout-minutes: 1
  env:
    TEST_OUTCOME: ${{ steps.tests.outcome }}
  run: |
    /usr/bin/python3 scripts/ci-report.py build || echo '::warning::CI report generation failed; consult the build/test log.'
    if [[ "$TEST_OUTCOME" == failure ]]; then exit 1; fi
```

The one-minute number is a starting budget, not measured runtime. Better still, print a very short phase/status synopsis from the test recipe's failure/EXIT path so a timeout that kills the later reporter has already left evidence; do not put lengthy diagnostics inside that trap. Adjust the reporter to emit a fileless annotation and Markdown synopsis before attempting per-test exports. Persist `say()` markers/exit status in `build/logs` so this is also useful to `just ci-report`. [L1][L2][G1]

**Cost:** zero new dependencies; one intentional second failed step per failed test job, explicitly named as a report rather than a new failure. Small Python 3.9-compatible changes and workflow conditions. **Compatibility:** native summary/CLI behavior is documented; cancellation execution and missing/incomplete result bundles remain best-effort. Keep original test failure authoritative. [G1][G3]

### 2. Add source-located test annotations and truthful infrastructure/crash summaries

**Change:** in `scripts/ci-report.py`, bound each subprocess, print stderr/status on export/read failure, fetch modern per-test details for actual source references, emit escaped `::error`/`::warning` commands, and render real headings plus bounded stack/tail detail. Keep all reporting functional without a bundle. Split/timeout simulator capture in `.github/workflows/ci.yml`; add a small targeted text extract to the summary, keeping full gzip/results in artifacts. [A1][G1][L2]

**Cost:** no packages, own a small amount of schema traversal and a fixture-based Python check (malformed/missing result, assertion with source, source-less preparation failure, crash). No `checks: write` or privileged fork workflow. **Compatibility:** Xcode 27 CLI/schema verified locally; actual runner bundles/Swift Testing locations and incomplete-bundle recovery **unknown until smoke-tested**. [A1]

### 3. Surface recovered retries instead of only red jobs

**Change:** inspect modern `tests`/`test-details` repetitions and generate a short warning when an assertion failed before passing, including attempt count and original error. Run the cheap summary inspection after completed tests (`success() || failure()`), not only when the outer retry file exists. Leave xcodebuild's exit verdict authoritative; a recovered failure is a warning, not an automatic red check. Preserve both outer bundles and label preparation retries separately from flaky assertions. [A1][P1][W2][L1]

**Cost:** no dependency if kept to a small parser; otherwise **replace expanded custom result formatting with one pinned xcresultparser CLI**, rather than layering both. Its documented flaky JUnit policy differs from our proposed warning-only treatment, so test that explicitly. **Compatibility:** modern APIs verified; real internal retry topology and Swift Testing parameterized cases **unknown**. [P1][P2][A1]

### 4. Add JUnit + one publisher only if test navigation needs its own check

**Change:** optionally generate per-scheme/per-attempt JUnit with existing xcbeautify (or xcresultparser if installed for rank 3), then use a **release-SHA-pinned** mikepenz action after testing. Start with `annotate_only: true`, `job_summary: true`, `detailed_summary: true`; add `checks: write` only if separate test checks provide value and restrict it to trusted contexts. Keep the native infrastructure report and failed-step log synopsis. Test `require_tests` policy so a missing XML does not obscure a known build/preparation failure. [B2][M1]

**Cost:** one Node action and XML configuration; no paid service/Ruby. Avoid publishing duplicate assertion annotations from both Python/xcbeautify/publisher: choose one owner. **Compatibility:** publisher consumes XML and is not tied to xcresult APIs; fidelity of our formatter's Swift Testing/retry XML and Xcode 27 logs **unknown**. DuckDuckGo provides a real adoption example, but mostly for macOS. [O7][B2][M1]

### 5. Add visual hosting / native symbolication only after evidence calls for them

**Change:** export failed attachments and host a very small selected report only if UI failures cannot be understood from assertions/activity text; use current XCTestHTMLReport's modern reader if a full browsable report is justified. For app crashes with unresolved app frames, preserve matching symbols and run Apple's CrashSymbolicator script before summarizing. [A1][A3][H1]

**Cost:** attachments alone have no dependency, but **no-download viewing needs deployment/retention/privacy design**; full HTML adds a pinned CLI and hosting. Symbolication needs correct Debug symbols and native Apple tooling, not a third-party Python dependency. **Compatibility:** hosted media, stable HTML release contents, and current CI dSYM availability **unknown**. These are lower priority than fixing text visibility. [A3][H1][U1]

### Skip for now

Skip overlapping problem matchers, the older kishikawakatsumi snapshot, a slido legacy bridge, fastlane merely for test reports, a privileged artifact-publication workflow merely for comments, full-time video capture, and paid CI dashboards. None is needed to fix the concrete log/summary visibility gaps; the older xcresult action also has a verified deprecated-API mismatch and external image-upload behavior. Do not add Codecov just because Element uses it: this research verified its use, **not its current free-tier terms or incremental value for this personal project**. Historical/flaky dashboards can be reconsidered after repeated failures make cross-run analysis necessary. [G4][K2][K3][S2][F1–F3][G6][O4]

## 6. Unknowns and acceptance checks before adoption

All third-party tools above need a real Xcode 27 fixture/run before adoption. Specifically unknown: hosted cancellation cleanup timing; best timeout budgets; missing/partial xcresult behavior; source locations for current Swift Testing failures; internal retry representation; automatic attachment availability with disabled verbose diagnostics; package-manager stable versus main HTML reader support; external image-server availability/privacy; matching simulator/test-runner dSYMs; and service free-tier terms. Do not infer compatibility from a README screenshot, an Xcode >=16 branch, or another app's runner label. [A1][L1][K3][H1][O4]

The smallest useful acceptance exercise is a temporary deliberately failed assertion, a failed runner/preparation case with no tests, and a timeout, then inspect **the browser summary, PR annotation, `gh run view RUN --log-failed`, and full job log**. Confirm reporting does not change xcodebuild's verdict, recovered retries remain labelled, export errors remain visible, and the original logs/bundles still upload. This is a proposed validation plan, **not performed research**.

## Evidence index

### Local sources and Apple CLI (checked October 7, 2026)

- **[L1]** `git rev-parse HEAD` → `c451ddf25225fc55dff307f1125573ea27a8cc78`; initial `git status --short` → modified `.github/workflows/ci.yml`, `AGENTS.md`, `README.md`, `justfile`, untracked `scripts/ci-report.py` and `docs/research/ci-ui-test-stall.md`. Working-tree `.github/workflows/ci.yml:25–65,69–109`, `justfile:71–123,171–177`, read before research. `git log --all --oneline --grep='report\|diagnostic'` found existing CI setup/preboot history, no earlier dedicated reporter change. Working-tree paths are deliberately **not immutable citations**.
- **[L2]** Working-tree `scripts/ci-report.py:15–17` (silent xcresult error), `20–47` (existing-symbol stack rendering), `56–66` (modern summary/diagnostics), `74–89` (phases/tail/summary fence), read October 7. No changes to this script by this research.
- **[L3]** `docs/research/ci-ui-test-stall.md`, uncommitted, checked October 7; exact `XCTWaiter handleStalledWait` diagnosis is unknown; local xcbeautify buffering probe and native diagnostics help are documented there.
- **[A1]** Commands run: `xcodebuild -version` → `Xcode 27.0 / Build version 27A266a`; `xcrun xcresulttool help get test-results` → six subcommands listed above; `xcrun xcresulttool help get object` → deprecated, `--legacy` required; `xcrun xcresulttool help export attachments` → manifest and `--only-failures`, `--filter`, `--test-id`; `xcrun xcresulttool get test-results summary --schema` → TestFailure properties `failureText`, string/URL identifiers; `xcrun xcresulttool get test-results test-details --schema` → TestNode `sourceLocation`, Repetition/Failure Message/Source Code Reference node kinds and `SourceLocation.filePath,lineNumber`. Commands exited successfully; no test bundle was processed.
- **[A2]** Apple, Xcode **16** release notes (**older**, 2024 generation), xcresulttool section / 118990069: https://developer.apple.com/documentation/xcode-release-notes/xcode-16-release-notes . Full structured official text read through https://developer.apple.com/tutorials/data/documentation/xcode-release-notes/xcode-16-release-notes.json . The precise legacy flag requirement in this report comes from installed Xcode 27 help, not an inferred old release-note entry.
- **[A3]** Apple, current symbolication guide (live docs, checked October 7): https://developer.apple.com/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report . Full structured source: https://developer.apple.com/tutorials/data/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report.json . Includes `xcrun crashlog`, `CrashSymbolicator.py`, `atos`, partially symbolicated reports and matching symbols.

### GitHub primary documentation (live documentation checked October 7)

- **[G1]** Workflow commands, annotation/group syntax and job summaries/limits: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands .
- **[G2]** Workflow syntax, step/job timeouts: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepstimeout-minutes and https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idtimeout-minutes .
- **[G3]** GitHub CLI `gh run view`, failed **step** selection and log fallback limitations: https://cli.github.com/manual/gh_run_view .
- **[G4]** Official toolkit problem matchers at `fa980c4100e53128102670562e9e293518900112`: https://github.com/actions/toolkit/blob/fa980c4100e53128102670562e9e293518900112/docs/problem-matchers.md ; workflow-command escaping implementation: https://github.com/actions/toolkit/blob/fa980c4100e53128102670562e9e293518900112/packages/core/src/command.ts .
- **[G5]** Checks create API permissions and 50 annotations **per request**: https://docs.github.com/en/rest/checks/runs#create-a-check-run .
- **[G6]** `pull_request_target` security warning: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request_target .
- **[G7]** Status conditions / `always()` caution: https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#always .
- **[G8]** GitHub CLI rerun flags: https://cli.github.com/manual/gh_run_rerun ; local `gh run rerun --help` → `--failed`, `--debug`, job `databaseId` guidance.
- **[G9]** Debugging variables, runner archive versus step logs: https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/enabling-debug-logging .

### Action/tool primary sources at pinned source snapshots

Publication ages vary; these are source snapshots checked October 7, **not promises of released-version support**. xcbeautify's snapshot is August 2026 (older than one month); legacy-action design/README screenshots are older historical material.

- **[U1]** upload-artifact at `cf430e030ddbb5b0abf93d22962f4752f3646cd9`: https://github.com/actions/upload-artifact/blob/cf430e030ddbb5b0abf93d22962f4752f3646cd9/README.md . retention, compression, artifact URL authentication/expiry, hidden-file behavior.
- **[B1]** xcbeautify at `513e4b12c3f6c965d1d3b66bd5cd9d635f03112d`: https://github.com/cpisciotta/xcbeautify/blob/513e4b12c3f6c965d1d3b66bd5cd9d635f03112d/README.md . GitHub renderer, unbuffered producer, pipefail.
- **[B2]** xcbeautify report flags and log-event-based JUnit accumulation: https://github.com/cpisciotta/xcbeautify/blob/513e4b12c3f6c965d1d3b66bd5cd9d635f03112d/Sources/xcbeautify/Xcbeautify.swift#L51-L58 and #L99-L119.
- **[M1]** mikepenz at `e7e7568d7d705fbb3dcbc6cc71f30632ff145a42`: https://github.com/mikepenz/action-junit-report/blob/e7e7568d7d705fbb3dcbc6cc71f30632ff145a42/README.md . Options/PR permissions/read-only annotation examples.
- **[D1]** dorny at `3d49bf4e0715e7fe48375099bd6b1058d42e673c`: https://github.com/dorny/test-reporter/blob/3d49bf4e0715e7fe48375099bd6b1058d42e673c/README.md . Supported reporter dialects, summaries, checks/forks.
- **[E1]** EnricoMi at `071ec54125241f64de06e2a790236c1fd8ce9dce`: https://github.com/EnricoMi/publish-unit-test-result-action/blob/071ec54125241f64de06e2a790236c1fd8ce9dce/README.md . macOS/non-Docker variant, summaries/comments/comparison, permissions and fork workflow.
- **[K1]** kishikawakatsumi at `e73cbd4b152e3e8d406a9efb39f174822c9f7649`: https://github.com/kishikawakatsumi/xcresulttool/blob/e73cbd4b152e3e8d406a9efb39f174822c9f7649/README.md . macOS Checks, coverage/activities/screenshots, action-specific truncation.
- **[K2]** Old get/export implementation: https://github.com/kishikawakatsumi/xcresulttool/blob/e73cbd4b152e3e8d406a9efb39f174822c9f7649/src/parser.ts#L19-L79 .
- **[K3]** External image-byte upload: https://github.com/kishikawakatsumi/xcresulttool/blob/e73cbd4b152e3e8d406a9efb39f174822c9f7649/src/attachment.ts#L54-L75 .
- **[S1]** slido fork README: https://github.com/slidoapp/xcresulttool/blob/edbcd9b1fbe55a179e669e5b7aa9a3930071ead2/README.md .
- **[S2]** Xcode >=16 legacy adaptation: https://github.com/slidoapp/xcresulttool/blob/edbcd9b1fbe55a179e669e5b7aa9a3930071ead2/src/parser.ts#L22-L85 ; attachment implementation: https://github.com/slidoapp/xcresulttool/blob/edbcd9b1fbe55a179e669e5b7aa9a3930071ead2/src/attachment.ts .
- **[P1]** xcresultparser outputs and precise flaky semantics: https://github.com/a7ex/xcresultparser/blob/95ca65d0bd56250ccd16331f5b0480a1a2c0c5e9/README.md .
- **[P2]** Modern API client: https://github.com/a7ex/xcresultparser/blob/95ca65d0bd56250ccd16331f5b0480a1a2c0c5e9/Sources/xcresultparser/SharedTypes/Services/XCResultToolClient.swift#L40-L55 .
- **[H1]** Current HTML reporter README, readers, attachments, hosting demo, exit-code limitations: https://github.com/XCTestHTMLReport/XCTestHTMLReport/blob/eb3b5ef5aefa0b5761ffe5b62537519491fc6b6d/README.md .
- **[F1]** fastlane trainer modern parser selection: https://github.com/fastlane/fastlane/blob/3d31dd995c222356bec72dcb5be515a4d1776ef1/trainer/lib/trainer/test_parser.rb#L104 .
- **[F2]** trainer modern xcresult command: https://github.com/fastlane/fastlane/blob/3d31dd995c222356bec72dcb5be515a4d1776ef1/trainer/lib/trainer/xcresult.rb#L35 .
- **[F3]** scan options: https://github.com/fastlane/fastlane/blob/3d31dd995c222356bec72dcb5be515a4d1776ef1/scan/lib/scan/options.rb .

### Real workflows, pinned current source

- **[O1]** NetNewsWire at `732fac89a9b27cb14200aacdee9f3e942e410542`: https://github.com/Ranchero-Software/NetNewsWire/blob/732fac89a9b27cb14200aacdee9f3e942e410542/.github/workflows/ci.yml#L88-L117 .
- **[O2]** Wikipedia at `b4e4fca2299ac9f64bbce813ab574900e4d7a587`: https://github.com/wikimedia/wikipedia-ios/blob/b4e4fca2299ac9f64bbce813ab574900e4d7a587/.github/workflows/run_ui_tests.yml .
- **[O3]** Wikipedia unit workflow and summary action: https://github.com/wikimedia/wikipedia-ios/blob/b4e4fca2299ac9f64bbce813ab574900e4d7a587/.github/workflows/run_unit_tests.yml ; https://github.com/wikimedia/wikipedia-ios/blob/b4e4fca2299ac9f64bbce813ab574900e4d7a587/.github/actions/coverage-summary/action.yml .
- **[O4]** Element at `3b40aadc98a007eb063eae7288e6f4b18162cd3e`: https://github.com/element-hq/element-x-ios/blob/3b40aadc98a007eb063eae7288e6f4b18162cd3e/.github/workflows/ui-tests.yml .
- **[O5]** Element direct xcodebuild/renderer example: https://github.com/element-hq/element-x-ios/blob/3b40aadc98a007eb063eae7288e6f4b18162cd3e/.github/workflows/compound-ios.yml .
- **[O6]** DuckDuckGo at `4b46aae14c44aa7044649466a6110eb1d31ba2a7`, iOS UI workflow: https://github.com/duckduckgo/apple-browsers/blob/4b46aae14c44aa7044649466a6110eb1d31ba2a7/.github/workflows/ios_ui_tests.yml .
- **[O7]** DuckDuckGo **macOS** report pipeline: https://github.com/duckduckgo/apple-browsers/blob/4b46aae14c44aa7044649466a6110eb1d31ba2a7/.github/workflows/macos_pr_checks.yml#L307-L433 .
- **[O8]** DuckDuckGo crash-enriched summary action: https://github.com/duckduckgo/apple-browsers/blob/4b46aae14c44aa7044649466a6110eb1d31ba2a7/.github/actions/process-test-results/action.yml .
- **[O9]** Additional tree inspection, command `GET /repos/OWNER/REPO/git/trees/SHA?recursive=1` through GitHub API: Ice Cubes `9efcb16e720f337a401cf61c8e300dd043368282`, https://github.com/Dimillian/IceCubesApp/tree/9efcb16e720f337a401cf61c8e300dd043368282/.github/workflows ; Mastodon `2ef5a0cbe5c88e2d48c51a40a9590c372100d968`, https://github.com/mastodon/mastodon-ios/tree/2ef5a0cbe5c88e2d48c51a40a9590c372100d968/.github/workflows ; Signal `861588c92e427de1f0ffd0d3ac013c29d8d5f0c4`, https://github.com/signalapp/Signal-iOS/tree/861588c92e427de1f0ffd0d3ac013c29d8d5f0c4/.github/workflows ; Kickstarter `ab124eb679a58056a1ae78bc25ce82050f01d80f`, https://github.com/kickstarter/ios-oss/tree/ab124eb679a58056a1ae78bc25ce82050f01d80f . Tree filtering found respectively 1, 4, 7 and 0 workflow files; these supplied no stronger relevant reporting example.

### Older firsthand practitioner sources

- **[W1]** Al Wold, February 7, 2024: https://alwold.com/posts/xcresults-on-github-actions/ . Firsthand demonstration, not current API authority.
- **[W2]** Antoine van der Lee, June 22, 2021: https://www.avanderlee.com/debugging/flaky-tests-test-repetitions/ . Firsthand testing guidance, not GitHub/Xcode 27 specification.
- **[W3]** Constantin Jacob / CircleCI, updated October 31, 2025: https://circleci.com/blog/xcodebuild-exit-code-65-what-it-is-and-how-to-solve-for-ios-and-macos-builds/ . CI-vendor experience; current runner root cause remains unknown.
