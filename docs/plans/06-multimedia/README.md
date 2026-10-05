# 06 · Multimedia: caché de archivos y fondos

## Objetivo

Contrato §11. Imágenes, videos y música de la iglesia disponibles **sin conexión** en el iPad: se
descargan a una caché local tras sincronizar, se muestran en "Agregar al servicio" y las imágenes
marcadas como fondo aparecen en el selector de fondos. Solo con el módulo Multimedia.

## Dependencias

Fases 02 y 04.

## Pasos

### 1. `MediaCache` (`Core/Media/`)
- Carpeta `Application Support/Media/<churchID>/<mediaID>-<updatedAt epoch>.<ext>` (excluida del respaldo de iCloud con
  `isExcludedFromBackup`).
- `actor MediaCache`: `localURL(for:)` si ya está; `ensureDownloaded(_ assets:)` que, tras cada sincronización, descarga en
  segundo plano lo que falte o cambió: pide `GET /media/:id/download-url` y descarga con una `URLSession` de **background**
  (sigue si la app pasa a segundo plano). Máximo 2 descargas a la vez; imágenes y música primero, videos después.
- Borra los archivos de medios borrados o reemplazados. Expone el estado por id (`notDownloaded`, `downloading(progress)`,
  `ready(URL)`, `failed`).
- Espacio: si el disco libre baja de 1 GB, pausa las descargas de video y muestra el aviso en el indicador de sincronización.

### 2. Biblioteca
- `LiveLibraryRepository.media(of:)` desde la copia local, mapeado a `MediaAsset` (extiéndelo con `localURL`, `downloadState`,
  `durationSeconds`, `width`, `height`, `isBackground`).
- "Agregar al servicio": miniaturas reales de las imágenes (cargadas desde el archivo local, reducidas con `ImageIO` para no
  llenar la memoria) y de los videos (primer cuadro con `AVAssetImageGenerator`, guardado en caché); duración real.
  Mientras un archivo no esté descargado, la celda muestra el progreso y no se puede seleccionar ("Descargando…").

### 3. Fondos
- `ProjectionBackground` admite una imagen: `enum Source { gradient([Color]), image(URL) }`.
- `LiveBackgroundRepository`: los 6 degradados de siempre + las imágenes con `isBackground` ya descargadas, en ese orden.
- `ProjectionCanvas` dibuja el fondo de imagen escalado para llenar (`scaledToFill`), con el mismo velo negro del 20 %.
- Si la imagen de fondo en uso se borra, la consola vuelve al primer degradado.

### 4. Contenido de imagen
- `ProjectionCanvas` en `.image`: muestra la imagen real a pantalla completa (`scaledToFit` sobre negro) en lugar del
  degradado de marcador. Mantén el marcador para las vistas previas.

## Criterios de aceptación

- Con archivos subidos desde la web: tras sincronizar se descargan, aparecen con miniatura, se proyectan sin conexión, y una
  imagen marcada como fondo aparece en el selector.
- `BuildProject` limpio; vistas previas sin cambios (siguen con marcadores).

## Desviaciones

- `ProjectionBackground` gana `imageURL: URL?` (los degradados quedan como colores) en lugar de un `enum Source`: el
  degradado sirve además de marcador mientras la imagen se decodifica. Los contenidos `.image`/`.video`/`.audio` de
  `Slide` y `ProjectionFrame` ganan `url: URL? = nil` (sin URL, las vistas previas siguen con marcadores).
- Las descargas usan una `URLSession` de background con delegado (`MediaDownloader`, más `IrisAppDelegate` para los
  eventos al relanzar). El progreso se publica en pasos de 10 % para no redibujar en cada fragmento.
- Las miniaturas de video (primer cuadro a 0,5 s) se guardan en `Caches/VideoThumbnails`, regenerables.
- El espacio libre se comprueba antes de cada video; con menos de 1 GB se omite y el indicador de sincronización avisa.
- Las descargas arrancan desde un `afterSync` del motor de sincronización, sin bloquearlo, y solo con el módulo
  Multimedia encendido. Cerrar sesión borra la caché.
- La música en descarga también aparece deshabilitada con "Descargando…" (la regla de la spec habla de celdas).
