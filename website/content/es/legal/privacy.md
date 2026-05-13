---
title: Política de privacidad
date: 2026-03-16
translationKey: privacy
---

## La versión corta

Dockyard no recoge datos personales. Tu código se queda en tu ordenador. Recogemos informes de error anónimos para mejorar la estabilidad.

## La aplicación

Dockyard es una aplicación nativa de macOS que se ejecuta completamente en tu ordenador. No:

- Envía tu código, contenido de proyectos ni salida de terminal a ningún servidor
- Requiere ninguna cuenta ni registro
- Rastrea tu comportamiento ni actividad
- Accede a archivos fuera de tus directorios de proyecto

Todos los datos de proyecto (nombres, directorios, configuraciones de flujos de trabajo) se almacenan localmente en tu ordenador en `~/.config/dockyard/`.

## Servicios de terceros

Dockyard se integra con herramientas que tú instalas y configuras:

- **Claude Code** (Anthropic) - al usar el agente de código, tu código y el contexto de la conversación se envían a la API de Anthropic. Es una conexión directa entre tu ordenador y Anthropic, sujeta a la [política de privacidad de Anthropic](https://www.anthropic.com/privacy). Dockyard no intercepta, almacena ni retransmite estos datos.
- **Codex** (OpenAI) - al usar Codex en la pestaña del agente de código, tu código y el contexto de la conversación se envían a la API de OpenAI. Es una conexión directa entre tu ordenador y OpenAI, sujeta a la [política de privacidad de OpenAI](https://openai.com/policies/privacy-policy/). Dockyard no intercepta, almacena ni retransmite estos datos.
- **GitHub CLI** - sujeto a la [política de privacidad de GitHub](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
- **Ghostty** - el motor de terminal integrado se ejecuta localmente sin actividad de red

Dockyard no actúa como intermediario para estos servicios. Tus claves de API y credenciales las gestiona cada herramienta directamente.

## Este sitio web

El sitio web de Dockyard (francesc.barnola.net) utiliza [Umami](https://umami.is/) para analíticas respetuosas con la privacidad. Umami no utiliza cookies, no recoge datos personales y cumple con el RGPD, CCPA y PECR. Todos los datos son agregados y anónimos.

No se utilizan otros scripts de seguimiento, redes publicitarias ni analíticas de terceros en este sitio web.

## Contacto

Para preguntas relacionadas con la privacidad, contacta con [David Poblador i Garcia](https://davidpoblador.com).
