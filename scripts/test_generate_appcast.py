#!/usr/bin/env python3
"""Tests for generate_appcast.py."""

import xml.etree.ElementTree as ET
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from generate_appcast import build_appcast


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
