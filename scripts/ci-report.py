#!/usr/bin/env python3
"""Report a CI test run from its build/ directory (or an extracted artifact), stdlib only.

Usage: ci-report.py <dir with results/*.xcresult and logs/>
Env:   TEST_OUTCOME      the test step's outcome (success/failure/cancelled/skipped); exit 1 only if "failure"
       GITHUB_STEP_SUMMARY, GITHUB_OUTPUT   appended to when set (`recovered=1` when a retry recovered a test)
Prints a diagnosis, phases, failures, crashes and log tails, with GitHub ::error/::warning annotations.
"""
import glob, json, os, subprocess, sys, tempfile, time, traceback

DEADLINE = time.time() + 150  # the workflow step is bounded; every subprocess shares this budget
out, md = [], []  # console lines, Markdown lines


def say(line=""):
    out.append(line)


def esc(s, prop=False):
    """Escape workflow-command data (and property values) as the GitHub runner expects."""
    s = str(s).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    return s.replace(":", "%3A").replace(",", "%2C") if prop else s


def annotate(level, msg, title="", path=None, line=None):
    props = []
    if path:
        ws = os.environ.get("GITHUB_WORKSPACE") or os.getcwd()
        rel = os.path.relpath(path, ws) if os.path.isabs(path) else path
        if not rel.startswith(".."):  # a path outside the checkout cannot be annotated
            props.append("file=" + esc(rel, True))
            if line:
                props.append("line=%d" % line)
    if title:
        props.append("title=" + esc(title, True))
    say("::%s %s::%s" % (level, ",".join(props), esc(msg[:900])) if props else "::%s::%s" % (level, esc(msg[:900])))


def xcr(*args, timeout=30):
    """Run xcresulttool and return its JSON; raise RuntimeError with stderr/exit status on any failure."""
    cmd = ["xcrun", "xcresulttool", *args]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=max(1, min(timeout, DEADLINE - time.time())))
    except subprocess.TimeoutExpired:
        raise RuntimeError("%s timed out" % " ".join(cmd[2:5]))
    if r.returncode:
        raise RuntimeError("%s exited %d: %s" % (" ".join(cmd[2:5]), r.returncode, r.stderr.strip()[:500]))
    try:
        return json.loads(r.stdout)
    except ValueError as e:
        raise RuntimeError("%s printed invalid JSON: %s" % (" ".join(cmd[2:5]), e))


def first_loc(node):
    """First sourceLocation anywhere in a test-details tree, as (path, line)."""
    if isinstance(node, dict):
        loc = node.get("sourceLocation")
        if loc and loc.get("filePath"):
            return loc["filePath"], loc.get("lineNumber")
        node = list(node.values())
    for v in node if isinstance(node, list) else []:
        if isinstance(v, (dict, list)) and (loc := first_loc(v)):
            return loc
    return None


def cases(node, suite=""):
    if node.get("nodeType") == "Test Case":
        yield node, suite
    for c in node.get("children", []):
        yield from cases(c, node["name"] if node.get("nodeType") == "Test Suite" else suite)


def parse(summary, tests, details):
    """summary/tests are `get test-results` JSON; details(test_id) fetches test-details (or None).
    Returns counts, failures (name, message, infra, loc) and recovered (name, attempts, message, loc)."""
    nodes = [(n, s) for root in tests.get("testNodes", []) for n, s in cases(root)]
    suite_of = {n.get("nodeIdentifier"): s for n, s in nodes}
    failures, recovered = [], []
    for f in summary.get("testFailures", []):
        tid = f.get("testIdentifierString") or f.get("testName")
        infra = suite_of.get(tid) == "System Failures"
        failures.append(dict(name=tid, message=f.get("failureText", ""), infra=infra,
                             loc=None if infra else first_loc(details(tid) or {})))
    for n, _ in nodes:
        reps = [c for c in n.get("children", []) if c.get("nodeType") == "Repetition"]
        bad = [r for r in reps if r.get("result") == "Failed"]
        if bad and reps[-1].get("result") == "Passed":
            msg = next((c["name"] for c in bad[0].get("children", []) if c.get("nodeType") == "Failure Message"), "")
            recovered.append(dict(name=n["nodeIdentifier"], attempts=len(reps), failed=len(bad), message=msg,
                                  loc=first_loc(details(n["nodeIdentifier"]) or {})))
    counts = {k: summary.get(k + "Tests", 0) for k in ("passed", "failed", "skipped")}
    infra = sum(f["infra"] for f in failures)  # the summary counts synthetic "System Failures" cases as tests; they are not
    counts["failed"] = max(0, counts["failed"] - infra)
    return dict(result=summary.get("result", "unknown"), total=max(0, summary.get("totalTestCount", 0) - infra), counts=counts,
                infra=infra, failures=failures, recovered=recovered)


def fence(lines):
    return "```\n" + "\n".join(lines).replace("```", "``\u200b`") + "\n```"


def details_block(title, lines):
    md.extend(["<details><summary>%s</summary>" % title.replace("<", "&lt;"), "", fence(lines), "", "</details>", ""])


def frames(thread, images):
    """One line per frame; a run of frames from dyld_sim (loader noise) or the same symbol collapses."""
    rows = []
    for f in thread["frames"]:
        img = images[f["imageIndex"]].get("name", "?") if f.get("imageIndex") is not None else "?"
        sym = (f.get("symbol") or "0x%x" % f.get("imageOffset", 0))[:100]
        key = img if img.startswith("dyld") else img + sym
        if rows and rows[-1][0] == key:
            rows[-1][2] += 1
        else:
            rows.append([key, "%s  %s" % (img, sym), 1])
    return ["  %s%s" % (r[1], "  (x%d)" % r[2] if r[2] > 1 else "") for r in rows][:40]


def crash(path):
    """(title, lines) for a .ips crash report, or None when it is not one."""
    try:
        with open(path, errors="replace") as f:
            c = json.loads(f.read().partition("\n")[2])
        exc, term = c.get("exception", {}), c.get("termination", {})
        lines = ["(%s)" % os.path.basename(path)]
        threads, fault = c.get("threads", []), c.get("faultingThread", 0)
        for label, i in (("triggered thread", fault), ("main thread", 0)):
            if i < len(threads) and not (label == "main thread" and i == fault):
                lines.append("%s %d:" % (label, i))
                lines.extend(frames(threads[i], c.get("usedImages", [])))
        return "%s: %s %s, %s" % (c.get("procName"), exc.get("type"), exc.get("signal"), term.get("indicator")), lines
    except (ValueError, KeyError, IndexError, AttributeError):
        return None


def report_bundle(bundle, level, ips):
    """Analyse one result bundle; returns its parse() dict, or None if it could not be read."""
    name = os.path.basename(bundle)
    try:
        summary = xcr("get", "test-results", "summary", "--path", bundle)
        tests = xcr("get", "test-results", "tests", "--path", bundle)
    except RuntimeError as e:
        say("%s: cannot read result bundle: %s" % (name, e))
        annotate(level, "%s: cannot read result bundle: %s" % (name, e), "CI result bundle unreadable")
        md.append("- **%s**: unreadable result bundle (`%s`)" % (name, str(e).replace("`", "'")))
        return None

    def details(tid):
        try:
            return xcr("get", "test-results", "test-details", "--path", bundle, "--test-id", tid)
        except RuntimeError as e:
            say("  (no source location for %s: %s)" % (tid, e))

    r = parse(summary, tests, details)
    c = r["counts"]
    say("%s: %s, %d tests ran: passed %d, failed %d, skipped %d; runner failures %d" %
        (name, r["result"], r["total"], c["passed"], c["failed"], c["skipped"], r["infra"]))
    md.append("| %s | %s | %d | %d | %d | %d | %d |" % (name, r["result"], r["total"], c["passed"], c["failed"], c["skipped"], r["infra"]))
    if r["total"] == 0:
        annotate(level, "%s: zero tests ran; this is an infrastructure failure, not a pass" % name, "No tests ran")
    for f in r["failures"]:
        say("FAIL %s: %s" % (f["name"], f["message"]))
        path, line = f["loc"] or (None, None)
        if f["infra"]:
            annotate(level, "%s: %s" % (f["name"], f["message"]), "Runner or preparation failure")
        else:
            annotate(level, f["message"], "Test failed: " + f["name"], path, line)
    for f in r["recovered"]:
        first = f["message"].splitlines()[0] if f["message"] else ""
        say("RECOVERED %s: failed %d of %d attempts, then passed: %s" % (f["name"], f["failed"], f["attempts"], first))
        path, line = f["loc"] or (None, None)
        annotate("warning", "Passed on retry (failed %d of %d attempts). First failure: %s" % (f["failed"], f["attempts"], first),
                 "Flaky test: " + f["name"], path, line)
    if r["failures"]:
        tmp = tempfile.mkdtemp()
        try:
            subprocess.run(["xcrun", "xcresulttool", "export", "diagnostics", "--path", bundle, "--output-path", tmp],
                           capture_output=True, timeout=max(1, min(60, DEADLINE - time.time())), check=True)
            ips += glob.glob(os.path.join(tmp, "**", "*.ips"), recursive=True)
        except (subprocess.SubprocessError, OSError) as e:
            say("%s: diagnostics export failed: %s" % (name, (getattr(e, "stderr", None) or b"").decode(errors="replace").strip() or e))
    return r


def main(root):
    outcome = os.environ.get("TEST_OUTCOME", "")
    level = "warning" if outcome == "success" else "error"  # a bundle from a recovered outer retry is only a warning
    bundles = sorted(glob.glob(os.path.join(root, "results", "*.xcresult")))
    logs = sorted(glob.glob(os.path.join(root, "logs", "*.log")))
    ips, results = glob.glob(os.path.join(root, "logs", "*.ips")), []
    md.extend(["## CI test report" + (" (test step: %s)" % outcome if outcome else ""), "", "@@DIAGNOSIS@@", "",
               "| Bundle | Result | Tests run | Passed | Failed | Skipped | Runner failures |", "| --- | --- | ---: | ---: | ---: | ---: | ---: |"])
    if not bundles:
        say("No result bundle in %s/results: the build or test run stopped before xcodebuild wrote one. "
            "That is an infrastructure failure, not a pass." % root)
        annotate(level, "No test result bundle was written (build or runner failed before tests ran); see the phase lines in the log",
                 "No test results")
    for b in bundles:
        results.append(report_bundle(b, level, ips))

    ok = [r for r in results if r]
    bad = [f for r in ok for f in r["failures"]]
    flaky = [f for r in ok for f in r["recovered"]]
    diag = []
    if not bundles:
        diag.append("No result bundle: the build or runner failed before any test ran (infrastructure failure, not a pass).")
    if len(ok) < len(results):
        diag.append("%d result bundle(s) could not be read." % (len(results) - len(ok)))
    if bundles and ok and not any(r["total"] for r in ok):
        diag.append("No tests ran: infrastructure failure, not a pass.")
    if bad and all(f["infra"] for f in bad):
        diag.append("The test runner failed before any test ran (preparation failure), not an assertion.")
    elif bad:
        diag.append("%d test failure(s)." % len([f for f in bad if not f["infra"]]))
        if any(f["infra"] for f in bad):
            diag.append("%d runner failure(s)." % len([f for f in bad if f["infra"]]))
    if flaky:
        diag.append("%d test(s) failed and then passed on retry (flaky): %s." % (len(flaky), ", ".join(f["name"] for f in flaky)))
        if os.environ.get("GITHUB_OUTPUT"):
            open(os.environ["GITHUB_OUTPUT"], "a").write("recovered=1\n")
    if not diag:
        diag.append("No failures found." if outcome in ("", "success") else "No failure found in the result bundles; see the log tail.")
    md[md.index("@@DIAGNOSIS@@")] = "**Diagnosis:** " + " ".join(diag)
    say("Diagnosis: " + " ".join(diag))

    if bad or flaky:
        md.extend(["", "### Tests", ""])
        for f in bad:
            md.append("- ❌ `%s`%s: %s" % (f["name"], " (%s:%s)" % (os.path.basename(f["loc"][0]), f["loc"][1]) if f["loc"] else "",
                                         f["message"].splitlines()[0][:300] if f["message"] else ""))
        for f in flaky:
            md.append("- ⚠️ `%s` failed %d of %d attempts, then passed: %s" % (f["name"], f["failed"], f["attempts"],
                                                                              f["message"].splitlines()[0][:300] if f["message"] else ""))
        md.append("")
        for f in bad:
            details_block("Full failure text: " + f["name"], f["message"].splitlines())
    for p in sorted(set(ips)):
        c = crash(p)
        if c:
            say("Crash: " + c[0])
            out.extend("  " + l for l in c[1])
            details_block("Crash: " + c[0], c[1])
    for log in logs:
        lines = open(log, errors="replace").read().splitlines()
        phases = [l for l in lines if l.startswith("[ci-test ")]
        say("--- %s: phases" % os.path.basename(log))
        out.extend(phases or ["(none recorded)"])
        say("--- last 30 lines")
        out.extend(lines[-30:])
        if phases:
            details_block("Phases: " + os.path.basename(log), phases)
        details_block("Last 30 lines: " + os.path.basename(log), lines[-30:])


if __name__ == "__main__":
    try:
        main(sys.argv[1] if len(sys.argv) > 1 else "build")
    except Exception:  # the reporter must never be what fails a green test step
        say("::warning::ci-report.py crashed; see the step log")
        say(traceback.format_exc())
        md.extend(["", "ci-report.py crashed:", "", fence(traceback.format_exc().splitlines())])
    print("\n".join(out))
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write("\n".join(md)[:900000] + "\n")
    sys.exit(1 if os.environ.get("TEST_OUTCOME") == "failure" else 0)
