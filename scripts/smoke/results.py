#!/usr/bin/env python3
"""Prints one `<step>|PASS|FAIL|SKIP` line per test case in an .xcresult bundle."""

import json
import subprocess
import sys

RESULTS = {"Passed": "PASS", "Failed": "FAIL", "Skipped": "SKIP"}


def test_cases(node):
    if node.get("nodeType") == "Test Case":
        yield node
    for child in node.get("children", []):
        yield from test_cases(child)


report = json.loads(subprocess.check_output(
    ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", sys.argv[1]]))
cases = [case for node in report["testNodes"] for case in test_cases(node)]
for case in sorted(cases, key=lambda c: c["name"]):
    # testSmoke_1_Login() -> Login
    step = case["name"].removesuffix("()").split("_", 2)[-1]
    print(f"{step}|{RESULTS.get(case['result'], 'FAIL')}")
