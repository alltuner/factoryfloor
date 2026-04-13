#!/usr/bin/env python3
# ABOUTME: Tests for generate_appcast.py.
# ABOUTME: Covers release notes, HTML entities, existing appcast merging, and deduplication.
"""Tests for generate_appcast.py."""

import tempfile
import xml.etree.ElementTree as ET
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from generate_appcast import build_appcast, SPARKLE_NS

NS = f"{{{SPARKLE_NS}}}"


def parse(xml_str: str) -> ET.Element:
    return ET.fromstring(xml_str)


def test_no_release_notes_omits_description() -> None:
    """When no release notes are provided, description element should be absent."""
    xml = build_appcast(
        version="1.0.0",
        signature="abc123",
        dmg_length=999,
        dmg_url="https://example.com/app.dmg",
    )
    root = parse(xml)
    item = root.find(".//item")
    assert item is not None, "Expected <item> element"
    desc = item.find("description")
    assert desc is None, "Expected no <description> when release_notes not provided"
    print("PASS: no_release_notes_omits_description")


def test_release_notes_embedded_as_description() -> None:
    """When release notes are provided, they should appear in a description element."""
    notes = "## What's New\n\n* Added feature X\n* Fixed bug Y"
    xml = build_appcast(
        version="1.2.0",
        signature="sig456",
        dmg_length=5000,
        dmg_url="https://example.com/app.dmg",
        release_notes=notes,
    )
    root = parse(xml)
    item = root.find(".//item")
    assert item is not None, "Expected <item> element"
    desc = item.find("description")
    assert desc is not None, "Expected <description> element when release_notes provided"
    assert notes in desc.text, f"Expected release notes in description, got: {desc.text}"
    print("PASS: release_notes_embedded_as_description")


def test_release_notes_with_html_entities() -> None:
    """Release notes with special XML characters should be handled safely."""
    notes = "Fix for <div> & \"quotes\" in output"
    xml = build_appcast(
        version="1.3.0",
        signature="sig789",
        dmg_length=3000,
        dmg_url="https://example.com/app.dmg",
        release_notes=notes,
    )
    # Should parse without error (XML-safe)
    root = parse(xml)
    desc = root.find(".//item/description")
    assert desc is not None
    assert notes in desc.text
    print("PASS: release_notes_with_html_entities")


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
    assert item is not None, "Expected <item> element"
    link = item.find("link")
    assert link is not None, "Expected <link> element in item"
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

    try:
        xml = build_appcast(
            version="1.1.0",
            signature="newsig",
            dmg_length=2000,
            dmg_url="https://example.com/app-1.1.0.dmg",
            release_notes="Bug fixes",
            existing_path=existing_path,
        )
        root = parse(xml)
        items = root.findall(".//item")
        assert len(items) == 2, f"Expected 2 items, got {len(items)}"

        # First item has cumulative description with both versions
        enc0 = items[0].find("enclosure")
        assert enc0.get(f"{NS}shortVersionString") == "1.1.0"
        desc0 = items[0].find("description")
        assert desc0 is not None
        assert "Bug fixes" in desc0.text
        assert "First release" in desc0.text
        assert 'data-sparkle-version="1.1.0"' in desc0.text
        assert 'data-sparkle-version="1.0.0"' in desc0.text

        # Second item (old) keeps its own description
        enc1 = items[1].find("enclosure")
        assert enc1.get(f"{NS}shortVersionString") == "1.0.0"
        desc1 = items[1].find("description")
        assert desc1 is not None and desc1.text == "First release"
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


def test_cumulative_description_includes_css_and_version_tags() -> None:
    """Cumulative description should have CSS for Sparkle version highlighting."""
    existing = """\
<?xml version='1.0' encoding='utf-8'?>
<rss version="2.0" xmlns:sparkle="https://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <title>Version 1.1.0</title>
      <description>&lt;p&gt;Middle release&lt;/p&gt;</description>
      <enclosure sparkle:version="1.1.0" sparkle:shortVersionString="1.1.0"
                 sparkle:edSignature="sig2" length="1500" url="https://example.com/1.1.dmg"
                 type="application/octet-stream" />
    </item>
    <item>
      <title>Version 1.0.0</title>
      <description>Initial release</description>
      <enclosure sparkle:version="1.0.0" sparkle:shortVersionString="1.0.0"
                 sparkle:edSignature="sig1" length="1000" url="https://example.com/1.0.dmg"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>"""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".xml", delete=False) as f:
        f.write(existing)
        existing_path = f.name

    try:
        xml = build_appcast(
            version="1.2.0",
            signature="sig3",
            dmg_length=2000,
            dmg_url="https://example.com/1.2.dmg",
            release_notes="<p>Latest stuff</p>",
            existing_path=existing_path,
        )
        root = parse(xml)
        desc = root.find(".//item/description")
        assert desc is not None

        # Should contain CSS with sparkle-installed-version rule
        assert "sparkle-installed-version" in desc.text

        # Should contain all three versions tagged
        assert 'data-sparkle-version="1.2.0"' in desc.text
        assert 'data-sparkle-version="1.1.0"' in desc.text
        assert 'data-sparkle-version="1.0.0"' in desc.text

        # Content from all versions present
        assert "Latest stuff" in desc.text
        assert "Middle release" in desc.text
        assert "Initial release" in desc.text
    finally:
        os.unlink(existing_path)
    print("PASS: cumulative_description_includes_css_and_version_tags")


def test_cumulative_descriptions_are_not_nested() -> None:
    """When existing items already have cumulative descriptions, versions must not duplicate."""
    # Build a real appcast with cumulative descriptions by chaining two releases.
    # This mirrors what happens in production: v1.0.0 is released, then v1.1.0
    # merges with v1.0.0's appcast, producing cumulative descriptions.
    with tempfile.NamedTemporaryFile(mode="w", suffix=".xml", delete=False) as f:
        xml_v1 = build_appcast(
            version="1.0.0",
            signature="sig1",
            dmg_length=1000,
            dmg_url="https://example.com/app-1.0.0.dmg",
            release_notes="<p>First release</p>",
        )
        f.write(xml_v1)
        path_v1 = f.name

    with tempfile.NamedTemporaryFile(mode="w", suffix=".xml", delete=False) as f:
        xml_v11 = build_appcast(
            version="1.1.0",
            signature="sig2",
            dmg_length=2000,
            dmg_url="https://example.com/app-1.1.0.dmg",
            release_notes="<p>Second release</p>",
            existing_path=path_v1,
        )
        f.write(xml_v11)
        existing_path = f.name

    os.unlink(path_v1)

    try:
        xml = build_appcast(
            version="1.2.0",
            signature="sig3",
            dmg_length=3000,
            dmg_url="https://example.com/app-1.2.0.dmg",
            release_notes="<p>Third release</p>",
            existing_path=existing_path,
        )
        root = parse(xml)
        desc = root.find(".//item/description")
        assert desc is not None

        # Each version should appear exactly once in the cumulative description
        text = desc.text
        assert text.count('data-sparkle-version="1.2.0"') == 1, "v1.2.0 should appear once"
        assert text.count('data-sparkle-version="1.1.0"') == 1, "v1.1.0 should appear once"
        assert text.count('data-sparkle-version="1.0.0"') == 1, "v1.0.0 should appear once"

        # Content from all three versions should be present
        assert "Third release" in text
        assert "Second release" in text
        assert "First release" in text
    finally:
        os.unlink(existing_path)
    print("PASS: cumulative_descriptions_are_not_nested")


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
