#!/usr/bin/env python3
# ABOUTME: Seeds an appcast.xml with historical releases from CHANGELOG.md.
# ABOUTME: One-time script to populate changelog history before the first accumulating release.
"""Seed an appcast.xml with historical releases from CHANGELOG.md.

Generates items for all versions found in CHANGELOG.md. These items have
release notes and links but no enclosure/DMG data (since those releases
already shipped). The generate_appcast.py script will prepend real items
with enclosure data on each new release.
"""

import re
import sys
import xml.etree.ElementTree as ET

SPARKLE_NS = "https://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)

REPO_URL = "https://github.com/alltuner/factoryfloor"

# Matches "## [0.1.70](...) (2026-04-13)" or "## 0.1.70 (2026-04-13)"
VERSION_PATTERN = re.compile(
    r"^## \[?(\d+\.\d+\.\d+)\]?"
    r"(?:\([^)]*\))?"
    r"\s*\((\d{4}-\d{2}-\d{2})\)",
)


def parse_changelog(text: str) -> list[dict[str, str]]:
    """Parse CHANGELOG.md into a list of {version, date, body} dicts."""
    releases: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    body_lines: list[str] = []

    for line in text.splitlines():
        match = VERSION_PATTERN.match(line)
        if match:
            if current is not None:
                current["body"] = "\n".join(body_lines).strip()
                releases.append(current)
            current = {"version": match.group(1), "date": match.group(2)}
            body_lines = []
        elif current is not None:
            body_lines.append(line)

    if current is not None:
        current["body"] = "\n".join(body_lines).strip()
        releases.append(current)

    return releases


def clean_body(body: str) -> str:
    """Strip noise from changelog entries to keep release notes user-facing."""
    # Remove trailing commit hash references like ([abc1234](https://...))
    body = re.sub(r"\s*\(\[[\da-f]+\]\([^)]+\)\)", "", body)
    # Remove issue/PR number links like ([#123](https://...))
    body = re.sub(r"\s*\(\[#\d+\]\([^)]+\)\)", "", body)
    # Remove standalone issue refs like , closes [#123](...)
    body = re.sub(r",?\s*closes\s+\[#\d+\]\([^)]+\)", "", body)
    # Remove CI and dependency update entries (not useful to end users)
    body = re.sub(r"^\* \*\*(?:ci|deps):\*\*.*\n?", "", body, flags=re.MULTILINE)
    # Remove empty sections (header followed by blank lines or end of string)
    body = re.sub(r"### [^\n]+\n+(?=### |\Z)", "", body)
    return body.strip()


def markdown_to_html(md: str) -> str:
    """Minimal markdown to HTML for changelog content."""
    lines = md.splitlines()
    html_parts: list[str] = []
    in_list = False

    for line in lines:
        stripped = line.strip()
        if not stripped:
            if in_list:
                html_parts.append("</ul>")
                in_list = False
            continue
        if stripped.startswith("### "):
            if in_list:
                html_parts.append("</ul>")
                in_list = False
            heading = stripped[4:]
            html_parts.append(f"<h4>{heading}</h4>")
        elif stripped.startswith("* "):
            if not in_list:
                html_parts.append("<ul>")
                in_list = True
            content = stripped[2:]
            # Bold scope prefix like **ci:**
            content = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", content)
            html_parts.append(f"<li>{content}</li>")
        else:
            html_parts.append(f"<p>{stripped}</p>")

    if in_list:
        html_parts.append("</ul>")

    return "\n".join(html_parts)


def build_seed_appcast(changelog_text: str) -> str:
    """Build an appcast XML with historical releases from CHANGELOG.md."""
    releases = parse_changelog(changelog_text)

    rss = ET.Element("rss")
    rss.set("version", "2.0")
    rss.set("xmlns:dc", "http://purl.org/dc/elements/1.1/")

    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "Factory Floor"
    ET.SubElement(channel, "link").text = "https://factory-floor.com"
    ET.SubElement(channel, "description").text = "Factory Floor updates"
    ET.SubElement(channel, "language").text = "en"

    ns = f"{{{SPARKLE_NS}}}"

    for release in releases:
        version = release["version"]
        body = clean_body(release["body"])
        if not body:
            continue

        html = markdown_to_html(body)

        item = ET.SubElement(channel, "item")
        ET.SubElement(item, "title").text = f"Version {version}"
        ET.SubElement(item, "link").text = f"{REPO_URL}/releases/tag/v{version}"
        ET.SubElement(item, "description").text = html

        # Enclosure with version info but no DMG data (historical releases)
        enclosure = ET.SubElement(item, "enclosure")
        enclosure.set(f"{ns}version", version)
        enclosure.set(f"{ns}shortVersionString", version)

    ET.indent(rss, space="  ")
    return ET.tostring(rss, encoding="unicode", xml_declaration=True)


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Seed appcast from CHANGELOG.md")
    parser.add_argument(
        "--changelog", default="CHANGELOG.md", help="Path to CHANGELOG.md"
    )
    parser.add_argument("--output", default="appcast-seed.xml", help="Output path")
    args = parser.parse_args()

    with open(args.changelog) as f:
        text = f.read()

    xml = build_seed_appcast(text)
    with open(args.output, "w") as f:
        f.write(xml)
        f.write("\n")

    releases = parse_changelog(text)
    print(f"Seeded {args.output} with {len(releases)} releases")


if __name__ == "__main__":
    main()
