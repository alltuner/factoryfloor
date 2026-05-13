---
title: Integritetspolicy
date: 2026-03-16
translationKey: privacy
---

## Kortversionen

Dockyard samlar inte in personlig data. Din kod stannar på din dator. Vi samlar in anonyma kraschrapporter för att förbättra stabiliteten.

## Applikationen

Dockyard är en inbyggd macOS-applikation som körs helt på din dator. Den:

- Skickar inte din kod, projektinnehåll eller terminalutdata till någon server
- Kräver inget konto eller registrering
- Spårar inte ditt beteende eller din aktivitet
- Kommer inte åt filer utanför dina projektkataloger

All projektdata (namn, kataloger, arbetsflödeskonfigurationer) lagras lokalt på din dator i `~/.config/dockyard/`.

## Tredjepartstjänster

Dockyard integrerar med verktyg som du själv installerar och konfigurerar:

- **Claude Code** (Anthropic) - när du använder kodningsagenten skickas din kod och konversationskontext till Anthropics API. Det är en direkt anslutning mellan din dator och Anthropic, som omfattas av [Anthropics integritetspolicy](https://www.anthropic.com/privacy). Dockyard fångar inte upp, lagrar eller vidarebefordrar dessa data.
- **Codex** (OpenAI) - när du använder Codex i kodningsagentfliken skickas din kod och konversationskontext till OpenAI:s API. Det är en direkt anslutning mellan din dator och OpenAI, som omfattas av [OpenAI:s integritetspolicy](https://openai.com/policies/privacy-policy/). Dockyard fångar inte upp, lagrar eller vidarebefordrar dessa data.
- **GitHub CLI** - omfattas av [GitHubs integritetspolicy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
- **Ghostty** - den inbyggda terminalmotorn körs lokalt utan nätverksaktivitet

Dockyard agerar inte som mellanhand för dessa tjänster. Dina API-nycklar och inloggningsuppgifter hanteras av varje verktyg direkt.

## Denna webbplats

Dockyards webbplats (francesc.barnola.net) använder [Umami](https://umami.is/) för integritetsvänlig analys. Umami använder inga cookies, samlar inte in personuppgifter och uppfyller GDPR, CCPA och PECR. All data är aggregerad och anonym.

Inga andra spårningsskript, annonsnätverk eller tredjepartsanalys används på denna webbplats.

## Kontakt

För integritetsfrågor, kontakta [David Poblador i Garcia](https://davidpoblador.com).
