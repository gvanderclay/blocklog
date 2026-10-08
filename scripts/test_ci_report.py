"""Self-check for ci-report.py: `/usr/bin/python3 scripts/test_ci_report.py`. Real bundles live in build/ (gitignored)."""
import importlib.util, json, os, subprocess, sys, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = importlib.util.spec_from_file_location("ci_report", os.path.join(HERE, "ci-report.py"))
ci = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ci)
INFRA = os.path.join(HERE, "..", "build", "ci-ui-failure")  # artifact of run 37690858618


def case(name, *children, result="Failed"):
    return dict(nodeType="Test Case", name=name, nodeIdentifier=name, result=result, children=list(children))


def tree(*cases_):
    suite = dict(nodeType="Test Suite", name="S", children=list(cases_))
    return dict(testNodes=[dict(nodeType="Test Plan", name="P", children=[suite])])


class Parse(unittest.TestCase):
    def test_failing_assertion_with_location(self):
        summary = dict(result="Failed", totalTestCount=1, failedTests=1,
                       testFailures=[dict(testIdentifierString="S/a()", failureText="XCTAssertEqual failed")])
        loc = dict(testRuns=[dict(sourceLocation=dict(filePath="/w/T.swift", lineNumber=7))])
        r = ci.parse(summary, tree(case("S/a()")), lambda tid: loc)
        self.assertEqual(r["failures"][0]["loc"], ("/w/T.swift", 7))
        self.assertFalse(r["failures"][0]["infra"])

    def test_system_failure_is_not_a_test(self):
        sysf = dict(nodeType="Test Suite", name="System Failures", children=[case("Runner (1) encountered an error")])
        t = dict(testNodes=[dict(nodeType="Test Plan", name="P", children=[sysf])])
        summary = dict(result="Failed", totalTestCount=1, failedTests=1,
                       testFailures=[dict(testIdentifierString="Runner (1) encountered an error", failureText="crashed")])
        r = ci.parse(summary, t, lambda tid: None)
        self.assertEqual((r["total"], r["counts"]["failed"], r["infra"], r["failures"][0]["infra"]), (0, 0, 1, True))

    def test_recovered_retry(self):
        reps = [dict(nodeType="Repetition", result="Failed", children=[dict(nodeType="Failure Message", name="boom")]),
                dict(nodeType="Repetition", result="Passed")]
        r = ci.parse(dict(result="Passed", totalTestCount=1), tree(case("S/b()", *reps, result="Passed")), lambda tid: None)
        self.assertEqual((r["failures"], r["recovered"][0]["attempts"], r["recovered"][0]["message"]), ([], 2, "boom"))

    def test_annotation_escaping(self):
        ci.out.clear()
        ci.annotate("error", "a%b\nc", "t:i,tle", os.path.join(os.getcwd(), "x.swift"), 3)
        self.assertEqual(ci.out[0], "::error file=x.swift,line=3,title=t%3Ai%2Ctle::a%25b%0Ac")
        ci.out.clear()
        ci.annotate("error", "m", path="/elsewhere/x.swift", line=3)
        self.assertEqual(ci.out[0], "::error::m")

    def test_crash_report(self):
        ips = json.dumps(dict(procName="Blocklog", exception=dict(type="EXC_CRASH", signal="SIGABRT"), termination=dict(indicator="x"),
                              faultingThread=0, usedImages=[dict(name="Blocklog")],
                              threads=[dict(frames=[dict(imageIndex=0, symbol="boom")])]))
        with tempfile.NamedTemporaryFile("w", suffix=".ips", delete=False) as f:
            f.write("{}\n" + ips)
        title, lines = ci.crash(f.name)
        self.assertIn("EXC_CRASH", title)
        self.assertIn("boom", lines[-1])
        self.assertIsNone(ci.crash(__file__))


def run(root, **env):
    return subprocess.run(["/usr/bin/python3", os.path.join(HERE, "ci-report.py"), root], capture_output=True, text=True,
                          env=dict(os.environ, **env))


class EndToEnd(unittest.TestCase):
    def test_missing_bundle(self):
        r = run(tempfile.mkdtemp(), TEST_OUTCOME="failure")
        self.assertEqual(r.returncode, 1)
        self.assertIn("::error title=No test results::No test result bundle", r.stdout)

    @unittest.skipUnless(os.path.isdir(INFRA), "needs build/ci-ui-failure")
    def test_runner_failure_no_tests(self):
        r = run(INFRA, TEST_OUTCOME="failure")
        self.assertEqual(r.returncode, 1)
        self.assertIn("::error title=Runner or preparation failure::", r.stdout)
        self.assertNotIn("file=", r.stdout.split("::error", 1)[1].splitlines()[0])
        self.assertIn("0 tests ran: passed 0, failed 0, skipped 0; runner failures 1", r.stdout)
        self.assertIn("No tests ran: infrastructure failure, not a pass.", r.stdout)
        self.assertIn("runner failed before any test ran", r.stdout)
        self.assertIn("::error title=No tests ran::", r.stdout)


if __name__ == "__main__":
    unittest.main()
