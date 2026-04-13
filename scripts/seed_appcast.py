#!/usr/bin/env python3
# ABOUTME: Seeds an appcast.xml with historical releases from CHANGELOG.md.
# ABOUTME: One-time script; generate_appcast.py handles ongoing releases.
"""Seed an appcast.xml with historical releases from CHANGELOG.md."""

import argparse
import xml.etree.ElementTree as ET

import changelog

SPARKLE_NS = "https://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)

REPO_URL = "https://github.com/alltuner/factoryfloor"


def main() -> None:
    p = argparse.ArgumentParser(description="Seed appcast from CHANGELOG.md")
    p.add_argument("--changelog", default="CHANGELOG.md")
    p.add_argument("--output", default="appcast-seed.xml")
    args = p.parse_args()

    with open(args.changelog) as f:
        releases = changelog.parse(f.read())

    ns = f"{{{SPARKLE_NS}}}"
    rss = ET.Element("rss")
    rss.set("version", "2.0")
    rss.set("xmlns:dc", "http://purl.org/dc/elements/1.1/")

    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "Factory Floor"
    ET.SubElement(channel, "link").text = "https://factory-floor.com"
    ET.SubElement(channel, "description").text = "Factory Floor updates"
    ET.SubElement(channel, "language").text = "en"

    for release in releases:
        body = changelog.clean_body(release["body"])
        if not body:
            continue
        v = release["version"]
        item = ET.SubElement(channel, "item")
        ET.SubElement(item, "title").text = f"Version {v}"
        ET.SubElement(item, "link").text = f"{REPO_URL}/releases/tag/v{v}"
        ET.SubElement(item, "description").text = changelog.to_html(body)
        enc = ET.SubElement(item, "enclosure")
        enc.set(f"{ns}version", v)
        enc.set(f"{ns}shortVersionString", v)

    ET.indent(rss, space="  ")
    xml = ET.tostring(rss, encoding="unicode", xml_declaration=True)
    with open(args.output, "w") as f:
        f.write(xml + "\n")
    print(f"Seeded {args.output} with {len(releases)} releases")


if __name__ == "__main__":
    main()
