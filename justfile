set shell := ["bash", "-euo", "pipefail", "-c"]

sim_name := env("SIM_NAME", "iPhone 17")
project := "Blocklog.xcodeproj"
derived := "build/DerivedData"
bundle_id := "com.gvanderclay.blocklog"
xcodegen := "mise exec -- xcodegen"
xcbeautify := "mise exec -- xcbeautify"
# A failing test otherwise starts a slow `simctl diagnose` that blocks for minutes.
no_diag := "-collect-test-diagnostics never"
# A hung test fails in minutes (allowances round up to whole minutes).
timeouts := "-test-timeouts-enabled YES -default-test-execution-time-allowance 240 -maximum-test-execution-time-allowance 300"
# Screenshots run only through `just screenshot`.
skip_shots := "-skip-testing:BlocklogUITests/ScreenshotTests"

default:
    @just --list

# First available simulator named sim_name on iOS 27.
_udid:
    @xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next(x["udid"] for r,ds in d.items() if "iOS-27" in r for x in ds if x["name"]=="{{sim_name}}"))'

# Generate Blocklog.xcodeproj from project.yml.
generate:
    @{{xcodegen}} generate --quiet

# Format the Swift sources in place with the toolchain's swift format; settings are in .swift-format.
fmt:
    xcrun swift format --in-place --recursive App Tests UITests scripts

# Synthesize the rest-end chime into App/Resources/rest-chime.caf.
chime:
    xcrun swift scripts/make-chime.swift

# Render the light, dark and tinted app icons into App/Resources/Assets.xcassets/AppIcon.appiconset.
icon:
    xcrun swift scripts/render-icon.swift

# Export Apple's SwiftUI Specialist and What's New in SwiftUI skills from Xcode into the gitignored .agents/skills/apple/.
skills:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    # The exporter writes all of Xcode's skills; keep the two SwiftUI ones.
    xcrun agent skills export --output-dir "$tmp"
    rm -rf .agents/skills/apple
    mkdir -p .agents/skills/apple
    mv "$tmp/swiftui-specialist" "$tmp/swiftui-whats-new-27" .agents/skills/apple/

# Run xcodebuild with logging, a fresh xcresult and beautified output.
_xcb name *args:
    @mkdir -p build/logs build/results
    xcodebuild -project {{project}} -derivedDataPath {{derived}} -resultBundlePath "build/results/{{name}}-$(date +%Y%m%d-%H%M%S).xcresult" {{args}} -jobs 2 COMPILER_INDEX_STORE_ENABLE=NO 2>&1 | tee build/logs/{{name}}.log | {{xcbeautify}}

# Build the app for the simulator.
build: generate
    @just _xcb build -scheme Blocklog -destination "id=$(just _udid)" build

# Compile the app and both test bundles without running them; the test recipes then only relink.
build-tests: generate
    @just _xcb build-tests -scheme Blocklog -destination "id=$(just _udid)" build-for-testing

# Run every test (unit and UI) on the simulator.
test: generate
    @just _xcb test -scheme Blocklog -destination "id=$(just _udid)" -parallel-testing-enabled NO {{no_diag}} {{timeouts}} {{skip_shots}} test

test-unit: generate
    @just _xcb test-unit -scheme BlocklogUnit -destination "id=$(just _udid)" -parallel-testing-enabled NO {{no_diag}} {{timeouts}} test

test-ui: generate
    @just _xcb test-ui -scheme BlocklogUI -destination "id=$(just _udid)" -parallel-testing-enabled NO {{no_diag}} {{timeouts}} {{skip_shots}} test

# Run one test, e.g. `just test-one BlocklogTests/hostedInApp()`.
test-one identifier: generate
    @just _xcb test-one -scheme Blocklog -destination "id=$(just _udid)" "-only-testing:{{identifier}}" -parallel-testing-enabled NO {{no_diag}} {{timeouts}} test

# CI and local test run for one scheme: BlocklogUnit or BlocklogUI.
ci-test scheme: generate
    #!/usr/bin/env bash
    set -euo pipefail
    udid=$(xcrun simctl list devices available --json | python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next(x["udid"] for r,ds in d.items() if r.endswith("iOS-27-0") for x in ds if x["name"]=="iPhone 17"))')
    log="build/logs/{{scheme}}.log"
    mkdir -p build/logs build/results
    : >"$log"
    # Phase lines go into the saved log too, for scripts/ci-report.py.
    say() { echo "[ci-test $(date +%H:%M:%S)] $*" | tee -a "$log"; }
    fail() { say "$1"; [[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::error::$1"; return 0; }
    # Boot and slim the simulator in the background while build-for-testing compiles; `wait` joins it before the tests.
    # simslim (pinned in mise.toml; every category off, no --except, docs/research/simulator-resources.md) shuts the
    # simulator down, reconfigures it and boots it again. `simslim status` needs a booted simulator and says "(slim)" when
    # slim, so locally the slim is skipped when it already is. Without simslim: stock boot locally, a failure on CI.
    # Bounded: simctl bootstatus and simslim have no reliable timeout and bootstatus has been seen to hang on CI
    # runners (docs/research/ci-ui-test-stall.md); perl's alarm kills them.
    prepare_simulator() {
        local t0=$SECONDS simslim slim=1
        simslim=$(command -v simslim || mise which simslim 2>/dev/null || true)
        if [[ -z $simslim ]]; then
            [[ -n "${GITHUB_ACTIONS:-}" ]] && { fail "simslim is not installed; not testing on a stock simulator."; return 1; }
            say "simslim not installed; booting the stock simulator"
            slim=0
        elif [[ -z "${GITHUB_ACTIONS:-}" ]]; then
            perl -e 'alarm shift; exec @ARGV' 300 xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
            if "$simslim" status "$udid" 2>&1 | tail -1 | grep -q '(slim)$'; then
                say "simulator already slim: $("$simslim" measure "$udid" 2>&1 | tail -1)"
                return 0
            fi
        fi
        if ((slim)); then
            say "slimming $udid"
            # Generous limits for a slow hosted runner's busy first boot; the alarm is the outer bound.
            if ! perl -e 'alarm shift; exec @ARGV' 840 "$simslim" --boot-timeout 13m --spawn-timeout 5m on "$udid" 2>&1 | tee -a "$log"; then
                fail "simslim failed after $((SECONDS - t0))s; not testing on a stock simulator."
                return 1
            fi
            say "slimmed in $((SECONDS - t0))s: $("$simslim" measure "$udid" 2>&1 | tail -1)"
            return 0
        fi
        say "booting $udid"
        perl -e 'alarm shift; exec @ARGV' 300 xcrun simctl bootstatus "$udid" -b >>"$log" 2>&1 || { fail "bootstatus failed after $((SECONDS - t0))s"; return 1; }
        say "booted in $((SECONDS - t0))s"
    }
    prepare_simulator &
    prep=$!
    extra=()
    [[ "{{scheme}}" == BlocklogUI ]] && extra=(-retry-tests-on-failure -test-iterations 2 -skip-testing:BlocklogUITests/ScreenshotTests)
    renderer=()
    [[ -n "${GITHUB_ACTIONS:-}" ]] && renderer=(--renderer github-actions)
    rm -rf "build/results/{{scheme}}.xcresult" "build/results/{{scheme}}-retry.xcresult"
    cas="$HOME/Library/Developer/Xcode/CompilationCache.noindex"
    common=(-project {{project}} -scheme "{{scheme}}" -destination "platform=iOS Simulator,id=$udid"
        -derivedDataPath {{derived}} CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO
        COMPILATION_CACHE_ENABLE_CACHING=YES COMPILATION_CACHE_CAS_PATH="$cas")
    # Without this, xcbeautify buffers its piped output until it exits, so a stalled CI run printed
    # nothing (docs/research/ci-ui-test-stall.md; xcbeautify's README recommends it).
    export NSUnbufferedIO=YES
    xcb=({{xcbeautify}} ${renderer[@]+"${renderer[@]}"})
    status=0
    xcodebuild build-for-testing "${common[@]}" -showBuildTimingSummary 2>&1 | tee -a "$log" | "${xcb[@]}" || status=$?
    say "build exited $status; compilation cache $(du -sh "$cas" 2>/dev/null | cut -f1)"
    if ((status != 0)); then
        # Don't hold the failure report back for up to the slim's 14-minute bound.
        say "build failed; stopping simulator preparation"
        pkill -P "$prep" 2>/dev/null || true
        kill "$prep" 2>/dev/null || true
        wait "$prep" 2>/dev/null || true
    else
        wait "$prep" || { say "simulator preparation failed"; status=1; }
    fi
    result="build/results/{{scheme}}.xcresult"
    while ((status == 0)); do
        xcodebuild test-without-building "${common[@]}" -resultBundlePath "$result" -parallel-testing-enabled NO \
            {{no_diag}} {{timeouts}} ${extra[@]+"${extra[@]}"} 2>&1 | tee -a "$log" | "${xcb[@]}" || status=$?
        say "tests exited $status"
        # A simulator's first boot keeps it busy for minutes, and on CI the test runner then started too
        # slowly to bootstrap (killed or aborted before any test ran). Retry that, once, on the warmer simulator.
        if ((status == 0)) || [[ $result == *-retry.xcresult ]] || ! grep -q "never finished bootstrapping" "$log"; then
            break
        fi
        msg="The test runner never started; retrying once. See $result."
        say "$msg"
        [[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::warning::$msg"
        status=0
        result="build/results/{{scheme}}-retry.xcresult"
    done
    say "exiting $status"
    exit "$status"

# Build, install and launch on the simulator.
run: build
    #!/usr/bin/env bash
    set -euo pipefail
    udid=$(just _udid)
    xcrun simctl boot "$udid" 2>/dev/null || true
    # Xcode 27 here ships no Simulator.app; the simulator runs headless and build/run.png shows the result.
    open -b com.apple.iphonesimulator 2>/dev/null || true
    xcrun simctl install "$udid" "{{derived}}/Build/Products/Debug-iphonesimulator/Blocklog.app"
    xcrun simctl launch "$udid" {{bundle_id}}
    sleep 8  # ponytail: fixed wait for the launch animation; poll the accessibility tree if it proves flaky
    xcrun simctl io "$udid" screenshot build/run.png

# Capture ScreenshotTests in light, dark and dark at the largest accessibility text size.
screenshot: generate
    #!/usr/bin/env bash
    set -euo pipefail
    udid=$(just _udid)
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" >/dev/null
    reset() { xcrun simctl ui "$udid" appearance light; xcrun simctl ui "$udid" content_size large; }
    trap reset EXIT
    rm -rf build/screenshots
    for mode in light dark ax-large; do
        case $mode in
            light) xcrun simctl ui "$udid" appearance light; xcrun simctl ui "$udid" content_size large ;;
            dark) xcrun simctl ui "$udid" appearance dark; xcrun simctl ui "$udid" content_size large ;;
            ax-large) xcrun simctl ui "$udid" appearance dark; xcrun simctl ui "$udid" content_size accessibility-extra-extra-extra-large ;;
        esac
        result="build/results/screenshot-$mode-$(date +%Y%m%d-%H%M%S).xcresult"
        mkdir -p build/logs build/results "build/screenshots/$mode"
        xcodebuild -project {{project}} -derivedDataPath {{derived}} -resultBundlePath "$result" \
            -scheme BlocklogUI -destination "id=$udid" -only-testing:BlocklogUITests/ScreenshotTests -parallel-testing-enabled NO {{no_diag}} {{timeouts}} test -jobs 2 COMPILER_INDEX_STORE_ENABLE=NO \
            2>&1 | tee "build/logs/screenshot-$mode.log" | {{xcbeautify}}
        xcrun xcresulttool export attachments --path "$result" --output-path "build/screenshots/$mode"
        # Exports are named by UUID; rename each to <screen-name>.png from the manifest.
        python3 -c 'import json,os,sys; d=sys.argv[1]; [os.rename(os.path.join(d, a["exportedFileName"]), os.path.join(d, a["suggestedHumanReadableName"].rsplit("_", 2)[0] + ".png")) for t in json.load(open(os.path.join(d, "manifest.json"))) for a in t["attachments"]]' "build/screenshots/$mode"
    done
    ls build/screenshots/*

# Build, sign, install and launch on the connected iPhone (or $DEVICE).
device: generate
    #!/usr/bin/env bash
    set -euo pipefail
    device="${DEVICE:-}"
    if [[ -z "$device" ]]; then
        devices=$(xcrun devicectl list devices | awk '/connected/ && /iPhone/ && /physical/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-/) print $i}')
        count=$(printf '%s' "$devices" | grep -c . || true)
        [[ "$count" == 1 ]] || { echo "Expected one connected iPhone, found $count. Set DEVICE=<identifier>." >&2; exit 1; }
        device=$devices
    fi
    # The phone itself, not generic/platform=iOS: a free team's profile needs the device registered, and this registers it.
    just _xcb device -scheme Blocklog -destination "id=$device" -allowProvisioningUpdates build
    xcrun devicectl device install app --device "$device" "{{derived}}/Build/Products/Debug-iphoneos/Blocklog.app"
    xcrun devicectl device process launch --device "$device" {{bundle_id}}

# Summarise a failed CI run: test failures, crash reports and log tail from its failure artifacts.
ci-report run:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf build/ci/{{run}}
    gh run download {{run}} --dir build/ci/{{run}}
    for d in build/ci/{{run}}/*/; do echo "=== $d"; /usr/bin/python3 scripts/ci-report.py "$d"; done
