# ABOUTME: Parses CHANGELOG.md and converts entries to filtered HTML.
# ABOUTME: Shared by generate_appcast.py and seed_appcast.py.
"""Parse CHANGELOG.md and convert entries to filtered, user-facing HTML."""

import re

_VERSION_RE = re.compile(
    r"^## \[?(\d+\.\d+\.\d+)\]?(?:\([^)]*\))?\s*\((\d{4}-\d{2}-\d{2})\)",
)


def parse(text: str) -> list[dict[str, str]]:
    """Parse CHANGELOG.md into [{version, date, body}, ...]."""
    releases: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    lines: list[str] = []

    for line in text.splitlines():
        m = _VERSION_RE.match(line)
        if m:
            if current:
                current["body"] = "\n".join(lines).strip()
                releases.append(current)
            current = {"version": m.group(1), "date": m.group(2)}
            lines = []
        elif current:
            lines.append(line)

    if current:
        current["body"] = "\n".join(lines).strip()
        releases.append(current)

    return releases


def clean_body(body: str) -> str:
    """Strip noise to keep only user-facing content."""
    body = re.sub(r"\s*\(\[[\da-f]+\]\([^)]+\)\)", "", body)  # commit hash links
    body = re.sub(r"\s*\(\[#\d+\]\([^)]+\)\)", "", body)  # PR number links
    body = re.sub(r",?\s*closes\s+\[#\d+\]\([^)]+\)", "", body)  # closes refs
    body = re.sub(r"^\* \*\*(?:ci|deps):\*\*.*\n?", "", body, flags=re.MULTILINE)
    body = re.sub(r"### [^\n]+\n+(?=### |\Z)", "", body)  # empty sections
    return body.strip()


def to_html(md: str) -> str:
    """Convert changelog markdown subset to HTML using regex substitutions."""
    html = re.sub(r"^### (.+)$", r"<h4>\1</h4>", md, flags=re.MULTILINE)
    html = re.sub(r"^\* (.+)$", r"<li>\1</li>", html, flags=re.MULTILINE)
    html = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", html)
    html = re.sub(r"((?:<li>[^\n]*</li>\n?)+)", r"<ul>\n\1</ul>", html)
    html = re.sub(r"\n{2,}", "\n", html)
    return html.strip()
