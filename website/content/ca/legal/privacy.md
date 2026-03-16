---
title: Política de privacitat
date: 2026-03-16
translationKey: privacy
---

## La versió curta

Factory Floor no recull, emmagatzema ni transmet cap dada personal. El teu codi es queda al teu ordinador.

## L'aplicació

Factory Floor és una aplicació nativa de macOS que s'executa completament al teu ordinador. No:

- Recull telemetria ni analítiques d'ús
- Envia dades a cap servidor remot
- Requereix cap compte ni registre
- Rastreja el teu comportament ni activitat
- Accedeix a fitxers fora dels teus directoris de projecte

Totes les dades de projecte (noms, directoris, configuracions de fluxos de treball) s'emmagatzemen localment a macOS UserDefaults al teu ordinador. Les sessions de terminal, les operacions de git i les interaccions amb l'agent de codi es fan directament entre el teu ordinador i els serveis respectius (GitHub, Anthropic) sense passar per cap infraestructura de Factory Floor.

## Serveis de tercers

Factory Floor s'integra amb eines que tu instal·les i configures:

- **Claude Code** (Anthropic) - quan utilitzes l'agent de codi, el teu codi i el context de la conversa s'envien a l'API d'Anthropic per al seu processament. Es tracta d'una connexió directa entre el teu ordinador i Anthropic, subjecta a la [política de privacitat d'Anthropic](https://www.anthropic.com/privacy). Factory Floor no intercepta, emmagatzema ni retransmet aquestes dades.
- **GitHub CLI** - subjecte a la [política de privacitat de GitHub](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
- **Ghostty** - el motor de terminal integrat s'executa localment sense activitat de xarxa

Factory Floor no actua com a intermediari per a aquests serveis. Les teves claus d'API i credencials les gestiona cada eina directament.

## Aquest lloc web

El lloc web de Factory Floor (factory-floor.com) utilitza [Umami](https://umami.is/) per a analítiques respectuoses amb la privacitat. Umami no utilitza galetes, no recull dades personals i compleix amb el RGPD, CCPA i PECR. Totes les dades són agregades i anònimes.

No s'utilitzen altres scripts de seguiment, xarxes publicitàries ni analítiques de tercers en aquest lloc web.

## Contacte

Per a preguntes relacionades amb la privacitat, contacta amb [David Poblador i Garcia](https://davidpoblador.com).
