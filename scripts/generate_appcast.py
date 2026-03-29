#!/usr/bin/env python3
"""Generate a Sparkle appcast.xml from release metadata and DMG signature."""

import argparse
import datetime
import os
import xml.etree.ElementTree as ET


def build_appcast(
    version: str,
    signature: str,
    dmg_length: int,
    dmg_url: str,
    min_os: str = "14.0",
    release_notes_url: str | None = None,
) -> str:
    rss = ET.Element("rss")
    rss.set("version", "2.0")
    rss.set("xmlns:sparkle", "https://www.andymatuschak.org/xml-namespaces/sparkle")
    rss.set("xmlns:dc", "http://purl.org/dc/elements/1.1/")

    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "Factory Floor"
    ET.SubElement(channel, "link").text = "https://factory-floor.com"
    ET.SubElement(channel, "description").text = "Factory Floor updates"
    ET.SubElement(channel, "language").text = "en"

    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"Version {version}"
    pub_date = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%a, %d %b %Y %H:%M:%S %z"
    )
    ET.SubElement(item, "pubDate").text = pub_date
    ET.SubElement(item, "sparkle:minimumSystemVersion").text = min_os
    if release_notes_url:
        ET.SubElement(item, "sparkle:releaseNotesLink").text = release_notes_url

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", dmg_url)
    enclosure.set("sparkle:version", version)
    enclosure.set("sparkle:shortVersionString", version)
    enclosure.set("sparkle:edSignature", signature)
    enclosure.set("length", str(dmg_length))
    enclosure.set("type", "application/octet-stream")

    ET.indent(rss, space="  ")
    xml_str = ET.tostring(rss, encoding="unicode", xml_declaration=True)
    return xml_str


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Sparkle appcast.xml")
    parser.add_argument("--version", required=True, help="Release version (semver)")
    parser.add_argument("--signature", required=True, help="Ed25519 signature from sign_update")
    parser.add_argument("--dmg-path", required=True, help="Path to the DMG file")
    parser.add_argument("--dmg-url", required=True, help="Download URL for the DMG")
    parser.add_argument("--release-notes-url", default=None, help="URL for release notes")
    parser.add_argument("--output", default="appcast.xml", help="Output path")
    args = parser.parse_args()

    dmg_length = os.path.getsize(args.dmg_path)
    xml = build_appcast(
        version=args.version,
        signature=args.signature,
        dmg_length=dmg_length,
        dmg_url=args.dmg_url,
        release_notes_url=args.release_notes_url,
    )

    with open(args.output, "w") as f:
        f.write(xml)
        f.write("\n")

    print(f"Generated {args.output} for v{args.version} ({dmg_length} bytes)")


if __name__ == "__main__":
    main()
