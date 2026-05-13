---
title: Privacy Policy
date: 2026-03-16
translationKey: privacy
---

## The short version

Dockyard does not collect personal data. Your code stays on your machine. We collect anonymous crash reports to improve stability.

## The application

Dockyard is a native macOS application that runs entirely on your computer. It does not:

- Send your code, project contents, or terminal output to any server
- Require an account or registration
- Track your behavior or activity
- Access files outside your project directories

All project data (names, directories, workstream configurations) is stored locally on your machine in `~/.config/dockyard/`.

## Third-party services

Dockyard integrates with tools you install and configure yourself:

- **Claude Code** (Anthropic) - when using the Coding Agent, your code and conversation context are sent to Anthropic's API. This is a direct connection between your machine and Anthropic, subject to [Anthropic's privacy policy](https://www.anthropic.com/privacy). Dockyard does not intercept, store, or relay this data.
- **Codex** (OpenAI) - when using Codex in the Coding Agent tab, your code and conversation context are sent to OpenAI's API. This is a direct connection between your machine and OpenAI, subject to [OpenAI's privacy policy](https://openai.com/policies/privacy-policy/). Dockyard does not intercept, store, or relay this data.
- **GitHub CLI** - subject to [GitHub's privacy policy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
- **Ghostty** - the embedded terminal engine runs locally with no network activity

Dockyard does not act as an intermediary for these services. Your API keys and credentials are managed by each tool directly.

## This website

The Dockyard website (francesc.barnola.net) uses [Umami](https://umami.is/) for privacy-friendly analytics. Umami does not use cookies, does not collect personal data, and complies with GDPR, CCPA, and PECR. All data is aggregated and anonymous.

No other tracking scripts, advertising networks, or third-party analytics are used on this website.

## Contact

For privacy-related questions, contact [David Poblador i Garcia](https://davidpoblador.com).
