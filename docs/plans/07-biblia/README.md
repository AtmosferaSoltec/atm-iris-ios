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

- `BibleStore` guarda el `BibleDownload` como `rvr1909-v<version>.json` y, aparte, `rvr1909.meta.json` con versión,
  `ETag` y nombre; al bajar una versión nueva borra la anterior.
- El progreso se mide leyendo la respuesta por bytes (`APIClient.sendRaw(_:expectedBytes:progress:)`) contra el
  `sizeBytes` de `GET /bible/translations`. Si ese tamaño es el del gzip, el porcentaje avanza más rápido de lo real
  (tope de 99 % hasta guardar).
- `BibleRepository` gana `availabilityUpdates()` y `prepare()`, con implementación por defecto "lista" para el mock.
  Abrir el selector antes de que termine la descarga en segundo plano se suma a esa misma descarga.
- La fecha de la última comprobación se guarda en `SyncState.bibleCheckedAt` de la copia local.
- La API todavía no tiene el módulo `/bible`: la prueba con Juan 3:16 queda para la fase 10.

- **Apagada para todo Iris (2026-10-07)**: la tabla `system_features` de la API tiene la Biblia en `false` mientras se
  resuelve la licencia de una versión en español. La API manda `modules.bible = false` y `availableModules.bible = false`
  (contrato §6) y sus rutas responden 404. El iPad no la ofrece: sin botón en la consola, sin interruptor en Módulos ni
  fila en el tile de Inicio, y no la descarga. El código queda intacto: al encenderla en la base vuelve sola.
- **Copia incompleta (corregido el 2026-10-07)**: `BibleStore.save` comparaba URLs al limpiar versiones viejas y en el
  dispositivo (`/var` frente a `/private/var`) borraba el texto recién escrito; quedaba el `meta.json` sin texto y la
  lista de libros vacía. Ahora compara por nombre, y un `meta.json` sin su texto cuenta como "no descargada".
