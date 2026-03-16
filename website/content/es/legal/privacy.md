---
title: Política de privacidad
date: 2026-03-16
translationKey: privacy
---

## La versión corta

Factory Floor no recoge, almacena ni transmite ningún dato personal. Tu código se queda en tu ordenador.

## La aplicación

Factory Floor es una aplicación nativa de macOS que se ejecuta completamente en tu ordenador. No:

- Recoge telemetría ni analíticas de uso
- Envía datos a ningún servidor remoto
- Requiere ninguna cuenta ni registro
- Rastrea tu comportamiento ni actividad
- Accede a archivos fuera de tus directorios de proyecto

Todos los datos de proyecto (nombres, directorios, configuraciones de flujos de trabajo) se almacenan localmente en macOS UserDefaults en tu ordenador. Las sesiones de terminal, las operaciones de git y las interacciones con el agente de código se realizan directamente entre tu ordenador y los servicios respectivos (GitHub, Anthropic) sin pasar por ninguna infraestructura de Factory Floor.

## Servicios de terceros

Factory Floor se integra con herramientas que tú instalas y configuras:

- **Claude Code** (Anthropic) - al usar el agente de código, tu código y el contexto de la conversación se envían a la API de Anthropic para su procesamiento. Es una conexión directa entre tu ordenador y Anthropic, sujeta a la [política de privacidad de Anthropic](https://www.anthropic.com/privacy). Factory Floor no intercepta, almacena ni retransmite estos datos.
- **GitHub CLI** - sujeto a la [política de privacidad de GitHub](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
- **Ghostty** - el motor de terminal integrado se ejecuta localmente sin actividad de red

Factory Floor no actúa como intermediario para estos servicios. Tus claves de API y credenciales las gestiona cada herramienta directamente.

## Este sitio web

El sitio web de Factory Floor (factory-floor.com) utiliza [Umami](https://umami.is/) para analíticas respetuosas con la privacidad. Umami no utiliza cookies, no recoge datos personales y cumple con el RGPD, CCPA y PECR. Todos los datos son agregados y anónimos.

No se utilizan otros scripts de seguimiento, redes publicitarias ni analíticas de terceros en este sitio web.

## Contacto

Para preguntas relacionadas con la privacidad, contacta con [David Poblador i Garcia](https://davidpoblador.com).
