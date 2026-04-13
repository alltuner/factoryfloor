#!/usr/bin/env python3
# ABOUTME: Tests for seed_appcast.py.
# ABOUTME: Covers changelog parsing, noise filtering, and markdown-to-HTML conversion.
"""Tests for seed_appcast.py."""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from seed_appcast import clean_body, parse_changelog, markdown_to_html


def test_clean_body_removes_ci_entries() -> None:
    body = """\
### Bug Fixes

* **ci:** download appcast from previous release, not latest
* DMG skyline clipped by Finder status bar"""
    result = clean_body(body)
    assert "ci:" not in result
    assert "DMG skyline clipped" in result
    print("PASS: clean_body_removes_ci_entries")


def test_clean_body_removes_deps_entries() -> None:
    body = """\
### Bug Fixes

* **deps:** update dependency foo to v2.0
* **deps:** update dependency bar to v3.0
* actual bug fix here"""
    result = clean_body(body)
    assert "deps:" not in result
    assert "actual bug fix here" in result
    print("PASS: clean_body_removes_deps_entries")


def test_clean_body_removes_empty_sections() -> None:
    body = """\
### Bug Fixes

* **ci:** only a ci entry

### Features

* real feature here"""
    result = clean_body(body)
    assert "Bug Fixes" not in result
    assert "Features" in result
    assert "real feature here" in result
    print("PASS: clean_body_removes_empty_sections")


def test_clean_body_returns_empty_when_all_filtered() -> None:
    body = """\
### Bug Fixes

* **ci:** increase Node heap size for Monaco editor build"""
    result = clean_body(body)
    assert result == ""
    print("PASS: clean_body_returns_empty_when_all_filtered")


if __name__ == "__main__":
    failures = 0
    for name, func in list(globals().items()):
        if name.startswith("test_") and callable(func):
            try:
                func()
            except (AssertionError, TypeError) as e:
                print(f"FAIL: {name}: {e}")
                failures += 1
    sys.exit(1 if failures else 0)
