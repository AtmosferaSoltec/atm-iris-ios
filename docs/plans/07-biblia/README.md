# 07 · Biblia sin conexión

## Objetivo

Contrato §13. La Reina-Valera 1909 completa en el iPad, descargada una vez y consultada sin conexión
desde el selector de Biblia que ya existe.

## Dependencias

Fase 01 (sesión). Independiente de la sincronización.

## Pasos

1. `BibleStore` (`Core/Bible/`):
   - Descarga `GET /bible/translations/rvr1909/download` (URLSession descomprime el gzip) y lo guarda tal cual en
     `Application Support/Bible/rvr1909-v<version>.json`, con el `ETag`.
   - Comprueba actualizaciones con `If-None-Match` como máximo una vez al día, en segundo plano, tras una sincronización.
   - Carga perezosa: decodifica el archivo una vez a una estructura en memoria (`[BookID: [[String]]]` + índice de libros) en un
     `actor`, fuera del hilo principal.
2. `LiveBibleRepository` implementa `BibleRepository` (`translationName`, `books()`, `verseCount`, `verses`) sobre `BibleStore`.
   Los libros mapean a `BibleBook` (`testament` old/new, número de capítulos).
3. Sin descargar todavía:
   - Se descarga sola tras la primera sincronización si el módulo Biblia está encendido.
   - Si el operador abre el selector antes de que termine: estado "Descargando la Biblia… {porcentaje}" con progreso; sin red,
     "Necesitas conexión para descargar la Biblia la primera vez." + "Reintentar".
4. El pasaje abierto en la consola mantiene el comportamiento de la spec §6.3 / §7.5 (capítulo completo, ‹ ›, pie "Juan 3:16").

## Criterios de aceptación

- Con la Biblia importada en la API: Juan 3:16 sale con el texto de 1909; en modo avión sigue funcionando.
- `BuildProject` limpio; vistas previas sin cambios.

## Desviaciones

_(Completar al cerrar la fase.)_
