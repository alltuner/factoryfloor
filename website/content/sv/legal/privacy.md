---
title: Integritetspolicy
date: 2026-03-16
translationKey: privacy
---

## Kortversionen

Factory Floor samlar inte in, lagrar eller överför någon personlig data. Din kod stannar på din dator.

## Applikationen

Factory Floor är en inbyggd macOS-applikation som körs helt på din dator. Den:

- Samlar inte in telemetri eller användningsanalys
- Skickar inte data till någon fjärrserver
- Kräver inget konto eller registrering
- Spårar inte ditt beteende eller din aktivitet
- Kommer inte åt filer utanför dina projektkataloger

All projektdata (namn, kataloger, arbetsflödeskonfigurationer) lagras lokalt i macOS UserDefaults på din dator. Terminalsessioner, git-operationer och interaktioner med kodningsagenten sker direkt mellan din dator och respektive tjänster (GitHub, Anthropic) utan att passera genom någon Factory Floor-infrastruktur.

## Tredjepartstjänster

Factory Floor integrerar med verktyg som du själv installerar och konfigurerar:

- **Claude Code** (Anthropic) - när du använder kodningsagenten skickas din kod och konversationskontext till Anthropics API för bearbetning. Det är en direkt anslutning mellan din dator och Anthropic, som omfattas av [Anthropics integritetspolicy](https://www.anthropic.com/privacy). Factory Floor fångar inte upp, lagrar eller vidarebefordrar dessa data.
- **GitHub CLI** - omfattas av [GitHubs integritetspolicy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
- **Ghostty** - den inbyggda terminalmotorn körs lokalt utan nätverksaktivitet

Factory Floor agerar inte som mellanhand för dessa tjänster. Dina API-nycklar och inloggningsuppgifter hanteras av varje verktyg direkt.

## Denna webbplats

Factory Floors webbplats (factory-floor.com) använder [Umami](https://umami.is/) för integritetsvänlig analys. Umami använder inga cookies, samlar inte in personuppgifter och uppfyller GDPR, CCPA och PECR. All data är aggregerad och anonym.

Inga andra spårningsskript, annonsnätverk eller tredjepartsanalys används på denna webbplats.

## Kontakt

För integritetsfrågor, kontakta [David Poblador i Garcia](https://davidpoblador.com).
