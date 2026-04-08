---
title: Datenschutzerklärung
date: 2026-03-16
translationKey: privacy
---

## Kurzfassung

Factory Floor sammelt keine personenbezogenen Daten. Dein Code bleibt auf deinem Rechner. Wir sammeln anonyme Absturzberichte zur Verbesserung der Stabilität.

## Die Anwendung

Factory Floor ist eine native macOS-Anwendung, die vollständig auf deinem Computer läuft. Sie:

- Sendet weder deinen Code, Projektinhalte noch Terminal-Ausgaben an einen Server
- Erfordert kein Konto oder Registrierung
- Verfolgt weder dein Verhalten noch deine Aktivitäten
- Greift nicht auf Dateien außerhalb deiner Projektverzeichnisse zu

Alle Projektdaten (Namen, Verzeichnisse, Workstream-Konfigurationen) werden lokal auf deinem Computer in `~/.config/factoryfloor/` gespeichert.

## Absturzberichte

Factory Floor verwendet [Sentry](https://sentry.io/) zum Sammeln anonymer Absturzberichte. Dies hilft uns, Stabilitätsprobleme zu identifizieren und zu beheben, insbesondere in der integrierten Terminal-Engine.

**Was gesammelt wird:**

- Absturz-Stacktraces und Fehlermeldungen
- App-Version und Build-Typ (Release oder Entwicklung)
- macOS-Version und Hardware-Architektur
- Erkennung von App-Hängern (Hauptthread blockiert >5 Sekunden)

**Was NICHT gesammelt wird:**

- Screenshots oder Terminal-Inhalte
- Dateipfade, Projektnamen oder Code
- Persönliche Informationen (Namen, E-Mail-Adressen, IP-Adressen)
- Tastatureingaben, Zwischenablage-Inhalte oder Surfaktivitäten

Absturzdaten werden von Sentry innerhalb der EU (Frankfurt) verarbeitet. Du kannst [Sentrys Datenschutzerklärung](https://sentry.io/privacy/) einsehen.

## Drittanbieterdienste

Factory Floor integriert sich mit Tools, die du selbst installierst und konfigurierst:

- **Claude Code** (Anthropic) — bei Nutzung des Coding-Agents werden dein Code und Gesprächskontext an Anthropics API gesendet. Dies ist eine direkte Verbindung zwischen deinem Rechner und Anthropic, die [Anthropics Datenschutzerklärung](https://www.anthropic.com/privacy) unterliegt. Factory Floor fängt diese Daten weder ab, speichert sie noch leitet sie weiter.
- **GitHub CLI** — unterliegt [GitHubs Datenschutzerklärung](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
- **Ghostty** — die integrierte Terminal-Engine läuft lokal ohne Netzwerkaktivität

Factory Floor agiert nicht als Vermittler für diese Dienste. Deine API-Schlüssel und Zugangsdaten werden von jedem Tool direkt verwaltet.

## Diese Website

Die Factory-Floor-Website (factory-floor.com) verwendet [Umami](https://umami.is/) für datenschutzfreundliche Analyse. Umami verwendet keine Cookies, sammelt keine personenbezogenen Daten und entspricht DSGVO, CCPA und PECR. Alle Daten sind aggregiert und anonym.

Keine weiteren Tracking-Skripte, Werbenetzwerke oder Drittanbieter-Analysen werden auf dieser Website verwendet.

## Kontakt

Für datenschutzbezogene Fragen kontaktiere [David Poblador i Garcia](https://davidpoblador.com).
