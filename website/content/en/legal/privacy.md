---
title: Privacy Policy
date: 2026-03-16
translationKey: privacy
---

## The short version

Factory Floor does not collect personal data. Your code stays on your machine. We collect anonymous crash reports to improve stability.

## The application

Factory Floor is a native macOS application that runs entirely on your computer. It does not:

- Send your code, project contents, or terminal output to any server
- Require an account or registration
- Track your behavior or activity
- Access files outside your project directories

All project data (names, directories, workstream configurations) is stored locally on your machine in `~/.config/factoryfloor/`.

## Crash reporting

Factory Floor uses [Sentry](https://sentry.io/) to collect anonymous crash reports. This helps us identify and fix stability issues, especially in the embedded terminal engine.

**What is collected:**

- Crash stack traces and error messages
- App version and build type (release or development)
- macOS version and hardware architecture
- App hang detection (main thread blocked >5 seconds)

**What is NOT collected:**

- Screenshots or terminal content
- File paths, project names, or code
- Personal information (names, emails, IP addresses)
- Keystrokes, clipboard content, or browsing activity

Crash data is processed by Sentry in the EU (Frankfurt). You can review [Sentry's privacy policy](https://sentry.io/privacy/).

## Third-party services

Factory Floor integrates with tools you install and configure yourself:

- **Claude Code** (Anthropic) - when using the Coding Agent, your code and conversation context are sent to Anthropic's API. This is a direct connection between your machine and Anthropic, subject to [Anthropic's privacy policy](https://www.anthropic.com/privacy). Factory Floor does not intercept, store, or relay this data.
- **GitHub CLI** - subject to [GitHub's privacy policy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
- **Ghostty** - the embedded terminal engine runs locally with no network activity

Factory Floor does not act as an intermediary for these services. Your API keys and credentials are managed by each tool directly.

## This website

The Factory Floor website (factory-floor.com) uses [Umami](https://umami.is/) for privacy-friendly analytics. Umami does not use cookies, does not collect personal data, and complies with GDPR, CCPA, and PECR. All data is aggregated and anonymous.

No other tracking scripts, advertising networks, or third-party analytics are used on this website.

## Contact

For privacy-related questions, contact [David Poblador i Garcia](https://davidpoblador.com).
