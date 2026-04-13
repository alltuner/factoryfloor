#!/usr/bin/env python3
# ABOUTME: Generates a Sparkle appcast.xml from release metadata and DMG signature.
# ABOUTME: Merges with existing appcast to accumulate changelog history across releases.
"""Generate a Sparkle appcast.xml from release metadata and DMG signature."""

import argparse
import datetime
import os
import re
import xml.etree.ElementTree as ET

SPARKLE_NS = "https://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)

# CSS injected into the cumulative release notes HTML. Sparkle (2.5+) adds the
# class "sparkle-installed-version" to the div whose data-sparkle-version matches
# the user's installed build. The general sibling combinator (~) hides everything
# older than the installed version.
RELEASE_NOTES_CSS = """\
body { font-family: -apple-system, sans-serif; font-size: 13px; line-height: 1.5; padding: 8px 12px; }
h3 { margin: 12px 0 4px; font-size: 15px; }
h4 { margin: 8px 0 4px; font-size: 13px; }
ul { margin: 4px 0; padding-left: 20px; }
li { margin: 2px 0; }
hr { border: none; border-top: 1px solid #ddd; margin: 12px 0; }
.sparkle-installed-version, .sparkle-installed-version ~ * { display: none; }
@media (prefers-color-scheme: dark) {
  body { color: #e0e0e0; }
  hr { border-color: #444; }
}"""

# Matches individual version-tagged divs inside cumulative descriptions.
# Content never contains nested divs (only h3/h4/ul/li/p), so non-greedy works.
_VERSION_DIV_RE = re.compile(
    r'<div data-sparkle-version="([^"]+)">(.*?)</div>',
    re.DOTALL,
)


def build_cumulative_description(
    current_version: str,
    current_notes: str | None,
    existing_items: list[ET.Element],
) -> str:
    """Build an HTML description with all versions, tagged with data-sparkle-version."""
    version_attr = f"{{{SPARKLE_NS}}}shortVersionString"
    sections: list[str] = []
    seen_versions: set[str] = set()

    if current_notes:
        seen_versions.add(current_version)
        sections.append(
            f'<div data-sparkle-version="{current_version}">'
            f"<h3>v{current_version}</h3>\n{current_notes}\n</div>"
        )

    for item in existing_items:
        enclosure = item.find("enclosure")
        if enclosure is None:
            continue
        version = enclosure.get(version_attr, "")
        if not version or version in seen_versions:
            continue
        desc = item.find("description")
        if desc is None or not desc.text or not desc.text.strip():
            continue

        text = desc.text.strip()
        # Existing items may already have cumulative descriptions containing
        # multiple version-tagged divs. Extract individual blocks to avoid
        # nesting an entire cumulative blob inside a new div.
        version_divs = list(_VERSION_DIV_RE.finditer(text))
        if version_divs:
            for m in version_divs:
                div_version = m.group(1)
                if div_version not in seen_versions:
                    seen_versions.add(div_version)
                    sections.append(m.group(0))
        else:
            # Legacy format: plain description without version tags.
            seen_versions.add(version)
            sections.append(
                f'<div data-sparkle-version="{version}">'
                f"<h3>v{version}</h3>\n{text}\n</div>"
            )

    if not sections:
        return current_notes or ""

    separator = "\n<hr>\n"
    body = separator.join(sections)
    return f"<style>{RELEASE_NOTES_CSS}</style>\n{body}"


def build_item(
    version: str,
    signature: str,
    dmg_length: int,
    dmg_url: str,
    description: str,
    min_os: str = "14.0",
) -> ET.Element:
    """Build a single appcast <item> element."""
    item = ET.Element("item")
    ET.SubElement(item, "title").text = f"Version {version}"
    ET.SubElement(
        item, "link"
    ).text = f"https://github.com/alltuner/factoryfloor/releases/tag/v{version}"
    pub_date = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%a, %d %b %Y %H:%M:%S %z"
    )
    ET.SubElement(item, "pubDate").text = pub_date
    ns = f"{{{SPARKLE_NS}}}"
    ET.SubElement(item, f"{ns}minimumSystemVersion").text = min_os

    if description:
        ET.SubElement(item, "description").text = description

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", dmg_url)
    enclosure.set(f"{ns}version", version)
    enclosure.set(f"{ns}shortVersionString", version)
    enclosure.set(f"{ns}edSignature", signature)
    enclosure.set("length", str(dmg_length))
    enclosure.set("type", "application/octet-stream")

    return item


def parse_existing_items(existing_path: str) -> list[ET.Element]:
    """Parse existing appcast XML and return its <item> elements."""
    if not os.path.exists(existing_path):
        return []
    try:
        tree = ET.parse(existing_path)
        return list(tree.findall(".//item"))
    except ET.ParseError:
        return []


def build_appcast(
    version: str,
    signature: str,
    dmg_length: int,
    dmg_url: str,
    min_os: str = "14.0",
    release_notes: str | None = None,
    existing_path: str | None = None,
) -> str:
    existing_items = parse_existing_items(existing_path) if existing_path else []

    cumulative_desc = build_cumulative_description(
        version, release_notes, existing_items
    )

    rss = ET.Element("rss")
    rss.set("version", "2.0")
    rss.set("xmlns:dc", "http://purl.org/dc/elements/1.1/")

    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "Factory Floor"
    ET.SubElement(channel, "link").text = "https://factory-floor.com"
    ET.SubElement(channel, "description").text = "Factory Floor updates"
    ET.SubElement(channel, "language").text = "en"

    new_item = build_item(
        version=version,
        signature=signature,
        dmg_length=dmg_length,
        dmg_url=dmg_url,
        description=cumulative_desc,
        min_os=min_os,
    )
    channel.append(new_item)

    # Append previous items (used by the in-app Homebrew update popover)
    version_attr = f"{{{SPARKLE_NS}}}shortVersionString"
    for old_item in existing_items:
        enclosure = old_item.find("enclosure")
        if enclosure is not None:
            old_version = enclosure.get(version_attr, "")
            if old_version == version:
                continue
        channel.append(old_item)

    ET.indent(rss, space="  ")
    xml_str = ET.tostring(rss, encoding="unicode", xml_declaration=True)
    return xml_str


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Sparkle appcast.xml")
    parser.add_argument("--version", required=True, help="Release version (semver)")
    parser.add_argument("--signature", required=True, help="Ed25519 signature from sign_update")
    parser.add_argument("--dmg-path", required=True, help="Path to the DMG file")
    parser.add_argument("--dmg-url", required=True, help="Download URL for the DMG")
    parser.add_argument("--release-notes", default=None, help="Release notes HTML to embed")
    parser.add_argument("--existing", default=None, help="Path to existing appcast.xml to merge with")
    parser.add_argument("--output", default="appcast.xml", help="Output path")
    args = parser.parse_args()

    dmg_length = os.path.getsize(args.dmg_path)
    xml = build_appcast(
        version=args.version,
        signature=args.signature,
        dmg_length=dmg_length,
        dmg_url=args.dmg_url,
        release_notes=args.release_notes,
        existing_path=args.existing,
    )

    with open(args.output, "w") as f:
        f.write(xml)
        f.write("\n")

    print(f"Generated {args.output} for v{args.version} ({dmg_length} bytes)")


if __name__ == "__main__":
    main()
