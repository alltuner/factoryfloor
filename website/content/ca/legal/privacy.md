---
title: Política de privacitat
date: 2026-03-16
translationKey: privacy
---

## La versió curta

Dockyard no recull dades personals. El teu codi es queda al teu ordinador. Recollim informes d'error anònims per millorar l'estabilitat.

## L'aplicació

Dockyard és una aplicació nativa de macOS que s'executa completament al teu ordinador. No:

- Envia el teu codi, contingut de projectes ni sortida de terminal a cap servidor
- Requereix cap compte ni registre
- Rastreja el teu comportament ni activitat
- Accedeix a fitxers fora dels teus directoris de projecte

Totes les dades de projecte (noms, directoris, configuracions de fluxos de treball) s'emmagatzemen localment al teu ordinador a `~/.config/dockyard/`.

## Informes d'error

Dockyard utilitza [Sentry](https://sentry.io/) per recollir informes d'error anònims. Això ens ajuda a identificar i corregir problemes d'estabilitat, especialment en el motor de terminal integrat.

**Què es recull:**

- Traces de pila d'errors i missatges d'error
- Versió de l'aplicació i tipus de compilació (producció o desenvolupament)
- Versió de macOS i arquitectura de maquinari
- Detecció de bloquejos de l'aplicació (fil principal bloquejat >5 segons)

**Què NO es recull:**

- Captures de pantalla ni contingut del terminal
- Rutes de fitxers, noms de projectes ni codi
- Informació personal (noms, correus electrònics, adreces IP)
- Pulsacions de tecles, contingut del porta-retalls ni activitat de navegació

Les dades d'error es processen per Sentry a la UE (Frankfurt). Pots consultar la [política de privacitat de Sentry](https://sentry.io/privacy/).

## Serveis de tercers

Dockyard s'integra amb eines que tu instal·les i configures:

- **Claude Code** (Anthropic) - quan utilitzes l'agent de codi, el teu codi i el context de la conversa s'envien a l'API d'Anthropic. Es tracta d'una connexió directa entre el teu ordinador i Anthropic, subjecta a la [política de privacitat d'Anthropic](https://www.anthropic.com/privacy). Dockyard no intercepta, emmagatzema ni retransmet aquestes dades.
- **Codex** (OpenAI) - quan utilitzes Codex a la pestanya de l'agent de codi, el teu codi i el context de la conversa s'envien a l'API d'OpenAI. Es tracta d'una connexió directa entre el teu ordinador i OpenAI, subjecta a la [política de privacitat d'OpenAI](https://openai.com/policies/privacy-policy/). Dockyard no intercepta, emmagatzema ni retransmet aquestes dades.
- **GitHub CLI** - subjecte a la [política de privacitat de GitHub](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
- **Ghostty** - el motor de terminal integrat s'executa localment sense activitat de xarxa

Dockyard no actua com a intermediari per a aquests serveis. Les teves claus d'API i credencials les gestiona cada eina directament.

## Aquest lloc web

El lloc web de Dockyard (francesc.barnola.net) utilitza [Umami](https://umami.is/) per a analítiques respectuoses amb la privacitat. Umami no utilitza galetes, no recull dades personals i compleix el RGPD, CCPA i PECR. Totes les dades són agregades i anònimes.

No s'utilitzen altres scripts de seguiment, xarxes publicitàries ni analítiques de tercers en aquest lloc web.

## Contacte

Per a preguntes relacionades amb la privacitat, contacta amb [David Poblador i Garcia](https://davidpoblador.com).
