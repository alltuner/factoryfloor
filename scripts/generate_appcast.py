#!/usr/bin/env python3
# ABOUTME: Generates a Sparkle appcast.xml from release metadata and DMG signature.
# ABOUTME: Builds cumulative release notes fresh from CHANGELOG.md on every release.
"""Generate a Sparkle appcast.xml from release metadata and DMG signature."""

import argparse
import datetime
import os
import xml.etree.ElementTree as ET

import changelog

SPARKLE_NS = "https://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)

CSS = """\
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


def build_description(version: str, changelog_text: str) -> str:
    """Build cumulative HTML from CHANGELOG.md, starting at the given version."""
    sections: list[str] = []
    found = False

    for entry in changelog.parse(changelog_text):
        if not found:
            if entry["version"] == version:
                found = True
            else:
                continue
        body = changelog.clean_body(entry["body"])
        if not body:
            continue
        html = changelog.to_html(body)
        v = entry["version"]
        sections.append(
            f'<div data-sparkle-version="{v}"><h3>v{v}</h3>\n{html}\n</div>'
        )

    if not sections:
        return ""
    return f"<style>{CSS}</style>\n" + "\n<hr>\n".join(sections)


def build_appcast(
    version: str,
    signature: str,
    dmg_length: int,
    dmg_url: str,
    min_os: str = "14.0",
    changelog_text: str | None = None,
    existing_path: str | None = None,
) -> str:
    # Parse existing items for carry-forward
    existing_items: list[ET.Element] = []
    if existing_path and os.path.exists(existing_path):
        try:
            existing_items = list(ET.parse(existing_path).findall(".//item"))
        except ET.ParseError:
            pass

    # Build RSS feed
    ns = f"{{{SPARKLE_NS}}}"
    rss = ET.Element("rss")
    rss.set("version", "2.0")
    rss.set("xmlns:dc", "http://purl.org/dc/elements/1.1/")

    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "Factory Floor"
    ET.SubElement(channel, "link").text = "https://factory-floor.com"
    ET.SubElement(channel, "description").text = "Factory Floor updates"
    ET.SubElement(channel, "language").text = "en"

    # New release item
    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"Version {version}"
    ET.SubElement(
        item, "link"
    ).text = f"https://github.com/alltuner/factoryfloor/releases/tag/v{version}"
    ET.SubElement(item, "pubDate").text = datetime.datetime.now(
        datetime.timezone.utc
    ).strftime("%a, %d %b %Y %H:%M:%S %z")
    ET.SubElement(item, f"{ns}minimumSystemVersion").text = min_os

    if changelog_text:
        desc = build_description(version, changelog_text)
        if desc:
            ET.SubElement(item, "description").text = desc

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", dmg_url)
    enclosure.set(f"{ns}version", version)
    enclosure.set(f"{ns}shortVersionString", version)
    enclosure.set(f"{ns}edSignature", signature)
    enclosure.set("length", str(dmg_length))
    enclosure.set("type", "application/octet-stream")

    # Carry forward previous items (used by the in-app Homebrew update popover)
    ver_attr = f"{ns}shortVersionString"
    for old in existing_items:
        enc = old.find("enclosure")
        if enc is not None and enc.get(ver_attr) == version:
            continue
        channel.append(old)

    ET.indent(rss, space="  ")
    return ET.tostring(rss, encoding="unicode", xml_declaration=True)


def main() -> None:
    p = argparse.ArgumentParser(description="Generate Sparkle appcast.xml")
    p.add_argument("--version", required=True)
    p.add_argument("--signature", required=True)
    p.add_argument("--dmg-path", required=True)
    p.add_argument("--dmg-url", required=True)
    p.add_argument("--changelog", default=None, help="Path to CHANGELOG.md")
    p.add_argument("--existing", default=None, help="Existing appcast.xml to merge items from")
    p.add_argument("--output", default="appcast.xml")
    args = p.parse_args()

    changelog_text = None
    if args.changelog:
        with open(args.changelog) as f:
            changelog_text = f.read()

    xml = build_appcast(
        version=args.version,
        signature=args.signature,
        dmg_length=os.path.getsize(args.dmg_path),
        dmg_url=args.dmg_url,
        changelog_text=changelog_text,
        existing_path=args.existing,
    )
    with open(args.output, "w") as f:
        f.write(xml + "\n")
    print(f"Generated {args.output} for v{args.version}")


if __name__ == "__main__":
    main()
