#!/usr/bin/env python3
# ABOUTME: Generates a Sparkle appcast.xml from release metadata and DMG signature.
# ABOUTME: Merges with existing appcast to accumulate changelog history across releases.
"""Generate a Sparkle appcast.xml from release metadata and DMG signature."""

import argparse
import datetime
import os
import xml.etree.ElementTree as ET


def build_item(
    version: str,
    signature: str,
    dmg_length: int,
    dmg_url: str,
    min_os: str = "14.0",
    release_notes: str | None = None,
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

    if release_notes:
        ET.SubElement(item, "description").text = release_notes

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", dmg_url)
    enclosure.set(f"{ns}version", version)
    enclosure.set(f"{ns}shortVersionString", version)
    enclosure.set(f"{ns}edSignature", signature)
    enclosure.set("length", str(dmg_length))
    enclosure.set("type", "application/octet-stream")

    return item


SPARKLE_NS = "https://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)


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
        min_os=min_os,
        release_notes=release_notes,
    )
    channel.append(new_item)

    # Append previous items, skipping any with the same version
    version_attr = f"{{{SPARKLE_NS}}}shortVersionString"
    for old_item in (parse_existing_items(existing_path) if existing_path else []):
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
