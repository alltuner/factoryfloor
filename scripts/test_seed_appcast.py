#!/usr/bin/env python3
# ABOUTME: Tests for changelog.py parsing and filtering.
# ABOUTME: Covers CHANGELOG.md parsing, noise filtering, and markdown-to-HTML conversion.
"""Tests for changelog.py."""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
import changelog


def test_clean_body_removes_ci_entries() -> None:
    body = """\
### Bug Fixes

* **ci:** download appcast from previous release, not latest
* DMG skyline clipped by Finder status bar"""
    result = changelog.clean_body(body)
    assert "ci:" not in result
    assert "DMG skyline clipped" in result
    print("PASS: clean_body_removes_ci_entries")


def test_clean_body_removes_deps_entries() -> None:
    body = """\
### Bug Fixes

* **deps:** update dependency foo to v2.0
* **deps:** update dependency bar to v3.0
* actual bug fix here"""
    result = changelog.clean_body(body)
    assert "deps:" not in result
    assert "actual bug fix here" in result
    print("PASS: clean_body_removes_deps_entries")


def test_clean_body_removes_empty_sections() -> None:
    body = """\
### Bug Fixes

* **ci:** only a ci entry

### Features

* real feature here"""
    result = changelog.clean_body(body)
    assert "Bug Fixes" not in result
    assert "Features" in result
    assert "real feature here" in result
    print("PASS: clean_body_removes_empty_sections")


def test_clean_body_returns_empty_when_all_filtered() -> None:
    body = """\
### Bug Fixes

* **ci:** increase Node heap size for Monaco editor build"""
    result = changelog.clean_body(body)
    assert result == ""
    print("PASS: clean_body_returns_empty_when_all_filtered")


def test_to_html_converts_headings_and_bullets() -> None:
    md = """\
### Features

* add cool feature
* another feature

### Bug Fixes

* fix a bug"""
    html = changelog.to_html(md)
    assert "<h4>Features</h4>" in html
    assert "<h4>Bug Fixes</h4>" in html
    assert "<li>add cool feature</li>" in html
    assert "<ul>" in html
    print("PASS: to_html_converts_headings_and_bullets")


def test_to_html_bolds_scope_prefixes() -> None:
    md = "* **worktrees:** fix prune prompt"
    html = changelog.to_html(md)
    assert "<b>worktrees:</b>" in html
    print("PASS: to_html_bolds_scope_prefixes")


def test_parse_extracts_versions() -> None:
    text = """\
## [1.2.0](https://example.com) (2026-04-13)

### Features

* feature A

## [1.1.0](https://example.com) (2026-04-12)

### Bug Fixes

* fix B"""
    releases = changelog.parse(text)
    assert len(releases) == 2
    assert releases[0]["version"] == "1.2.0"
    assert releases[1]["version"] == "1.1.0"
    assert "feature A" in releases[0]["body"]
    print("PASS: parse_extracts_versions")


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
