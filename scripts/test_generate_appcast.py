#!/usr/bin/env python3
# ABOUTME: Tests for generate_appcast.py.
# ABOUTME: Covers cumulative descriptions from CHANGELOG.md, existing appcast merging, and noise filtering.
"""Tests for generate_appcast.py."""

import tempfile
import xml.etree.ElementTree as ET
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from generate_appcast import build_appcast, SPARKLE_NS

NS = f"{{{SPARKLE_NS}}}"

SAMPLE_CHANGELOG = """\
# Changelog

## [1.2.0](https://example.com) (2026-04-13)

### Features

* add cool new feature

### Bug Fixes

* **ci:** fix build step
* **deps:** update dependency foo to v2
* fix actual user-facing bug

## [1.1.0](https://example.com) (2026-04-12)

### Features

* show cumulative changelog in update popover ([#18](https://example.com)) ([abc1234](https://example.com))

## [1.0.0](https://example.com) (2026-04-11)

### Bug Fixes

* **ci:** increase heap size
* **deps:** update dependency bar to v3

## [0.9.0](https://example.com) (2026-04-10)

### Features

* initial release
"""


def parse(xml_str: str) -> ET.Element:
    return ET.fromstring(xml_str)


def test_no_changelog_omits_description() -> None:
    """When no changelog is provided, description element should be absent."""
    xml = build_appcast(
        version="1.0.0",
        signature="abc123",
        dmg_length=999,
        dmg_url="https://example.com/app.dmg",
    )
    root = parse(xml)
    item = root.find(".//item")
    assert item is not None
    desc = item.find("description")
    assert desc is None, "Expected no <description> when changelog not provided"
    print("PASS: no_changelog_omits_description")


def test_description_built_from_changelog() -> None:
    """Description should contain version-tagged sections from CHANGELOG.md."""
    xml = build_appcast(
        version="1.2.0",
        signature="sig",
        dmg_length=1000,
        dmg_url="https://example.com/app.dmg",
        changelog_text=SAMPLE_CHANGELOG,
    )
    root = parse(xml)
    desc = root.find(".//item/description")
    assert desc is not None
    text = desc.text

    # Current and older versions should be present
    assert 'data-sparkle-version="1.2.0"' in text
    assert 'data-sparkle-version="1.1.0"' in text
    assert 'data-sparkle-version="0.9.0"' in text

    # User-facing content should be present
    assert "add cool new feature" in text
    assert "fix actual user-facing bug" in text
    assert "cumulative changelog" in text
    assert "initial release" in text

    # CSS for Sparkle version hiding should be present
    assert "sparkle-installed-version" in text
    print("PASS: description_built_from_changelog")


def test_ci_and_deps_entries_are_filtered() -> None:
    """CI and dependency entries should not appear in the description."""
    xml = build_appcast(
        version="1.2.0",
        signature="sig",
        dmg_length=1000,
        dmg_url="https://example.com/app.dmg",
        changelog_text=SAMPLE_CHANGELOG,
    )
    root = parse(xml)
    desc = root.find(".//item/description")
    assert desc is not None
    text = desc.text
    assert "ci:" not in text, "CI entries should be filtered"
    assert "deps:" not in text, "Deps entries should be filtered"
    print("PASS: ci_and_deps_entries_are_filtered")


def test_version_with_only_noise_is_skipped() -> None:
    """A version whose entries are all ci/deps should not appear in the changelog."""
    xml = build_appcast(
        version="1.2.0",
        signature="sig",
        dmg_length=1000,
        dmg_url="https://example.com/app.dmg",
        changelog_text=SAMPLE_CHANGELOG,
    )
    root = parse(xml)
    desc = root.find(".//item/description")
    assert desc is not None
    text = desc.text
    # v1.0.0 only has ci/deps entries, so it should be absent
    assert 'data-sparkle-version="1.0.0"' not in text, "Version with only noise should be skipped"
    print("PASS: version_with_only_noise_is_skipped")


def test_each_version_appears_exactly_once() -> None:
    """No version should be duplicated in the cumulative description."""
    xml = build_appcast(
        version="1.2.0",
        signature="sig",
        dmg_length=1000,
        dmg_url="https://example.com/app.dmg",
        changelog_text=SAMPLE_CHANGELOG,
    )
    root = parse(xml)
    desc = root.find(".//item/description")
    assert desc is not None
    text = desc.text
    assert text.count('data-sparkle-version="1.2.0"') == 1
    assert text.count('data-sparkle-version="1.1.0"') == 1
    assert text.count('data-sparkle-version="0.9.0"') == 1
    print("PASS: each_version_appears_exactly_once")


def test_commit_hashes_and_pr_links_are_stripped() -> None:
    """Commit hashes and PR links from release-please should be cleaned up."""
    xml = build_appcast(
        version="1.1.0",
        signature="sig",
        dmg_length=1000,
        dmg_url="https://example.com/app.dmg",
        changelog_text=SAMPLE_CHANGELOG,
    )
    root = parse(xml)
    desc = root.find(".//item/description")
    assert desc is not None
    text = desc.text
    assert "abc1234" not in text, "Commit hashes should be stripped"
    assert "#18" not in text, "PR number links should be stripped"
    assert "cumulative changelog" in text, "Content should remain"
    print("PASS: commit_hashes_and_pr_links_are_stripped")


def test_item_contains_release_link() -> None:
    """Each item should have a <link> pointing to the GitHub release."""
    xml = build_appcast(
        version="1.4.0",
        signature="sigabc",
        dmg_length=2000,
        dmg_url="https://example.com/app.dmg",
    )
    root = parse(xml)
    item = root.find(".//item")
    assert item is not None
    link = item.find("link")
    assert link is not None
    assert link.text == "https://github.com/alltuner/factoryfloor/releases/tag/v1.4.0"
    print("PASS: item_contains_release_link")


def test_merges_with_existing_appcast() -> None:
    """New item should be prepended, existing items preserved."""
    existing = """\
<?xml version='1.0' encoding='utf-8'?>
<rss version="2.0" xmlns:sparkle="https://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <title>Version 1.0.0</title>
      <link>https://github.com/alltuner/factoryfloor/releases/tag/v1.0.0</link>
      <description>First release</description>
      <enclosure url="https://example.com/app-1.0.0.dmg"
                 sparkle:version="1.0.0"
                 sparkle:shortVersionString="1.0.0"
                 sparkle:edSignature="oldsig"
                 length="1000"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>"""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".xml", delete=False) as f:
        f.write(existing)
        existing_path = f.name

    changelog_text = """\
## [1.1.0](https://example.com) (2026-04-12)

### Features

* new feature

## [1.0.0](https://example.com) (2026-04-11)

### Features

* first release
"""

    try:
        xml = build_appcast(
            version="1.1.0",
            signature="newsig",
            dmg_length=2000,
            dmg_url="https://example.com/app-1.1.0.dmg",
            changelog_text=changelog_text,
            existing_path=existing_path,
        )
        root = parse(xml)
        items = root.findall(".//item")
        assert len(items) == 2, f"Expected 2 items, got {len(items)}"

        # First item is the new version
        enc0 = items[0].find("enclosure")
        assert enc0.get(f"{NS}shortVersionString") == "1.1.0"

        # Second item (old) is preserved
        enc1 = items[1].find("enclosure")
        assert enc1.get(f"{NS}shortVersionString") == "1.0.0"
    finally:
        os.unlink(existing_path)
    print("PASS: merges_with_existing_appcast")


def test_deduplicates_same_version() -> None:
    """Re-releasing the same version should replace the old item, not duplicate it."""
    existing = """\
<?xml version='1.0' encoding='utf-8'?>
<rss version="2.0" xmlns:sparkle="https://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <title>Version 1.0.0</title>
      <enclosure url="https://example.com/app-1.0.0.dmg"
                 sparkle:version="1.0.0"
                 sparkle:shortVersionString="1.0.0"
                 sparkle:edSignature="oldsig"
                 length="1000"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>"""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".xml", delete=False) as f:
        f.write(existing)
        existing_path = f.name

    try:
        xml = build_appcast(
            version="1.0.0",
            signature="newsig",
            dmg_length=1500,
            dmg_url="https://example.com/app-1.0.0-fixed.dmg",
            existing_path=existing_path,
        )
        root = parse(xml)
        items = root.findall(".//item")
        assert len(items) == 1, f"Expected 1 item (deduplicated), got {len(items)}"
        enc = items[0].find("enclosure")
        assert enc.get(f"{NS}edSignature") == "newsig"
    finally:
        os.unlink(existing_path)
    print("PASS: deduplicates_same_version")


def test_handles_missing_existing_file() -> None:
    """When existing file doesn't exist, should produce single-item appcast."""
    xml = build_appcast(
        version="1.0.0",
        signature="sig",
        dmg_length=1000,
        dmg_url="https://example.com/app.dmg",
        existing_path="/nonexistent/appcast.xml",
    )
    root = parse(xml)
    items = root.findall(".//item")
    assert len(items) == 1, f"Expected 1 item, got {len(items)}"
    print("PASS: handles_missing_existing_file")


def test_versions_before_current_are_excluded() -> None:
    """Only the current version and older should appear, not newer versions."""
    xml = build_appcast(
        version="1.1.0",
        signature="sig",
        dmg_length=1000,
        dmg_url="https://example.com/app.dmg",
        changelog_text=SAMPLE_CHANGELOG,
    )
    root = parse(xml)
    desc = root.find(".//item/description")
    assert desc is not None
    text = desc.text
    # 1.2.0 is newer than 1.1.0 and should not appear
    assert 'data-sparkle-version="1.2.0"' not in text
    # 1.1.0 and older should appear
    assert 'data-sparkle-version="1.1.0"' in text
    assert 'data-sparkle-version="0.9.0"' in text
    print("PASS: versions_before_current_are_excluded")


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
