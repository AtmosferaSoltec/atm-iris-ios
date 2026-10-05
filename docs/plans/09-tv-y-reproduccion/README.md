# 09 · TV y reproducción reales

## Objetivo

Lo que la maqueta simulaba (spec §1, §7.2–7.4, §12.6 adaptado a iPad): el contenido se proyecta en
una **pantalla externa** real (HDMI o AirPlay) y la música y el video se reproducen de verdad.

## Dependencias

Fases 06 (archivos locales) y 07 (Biblia). La lógica de presentación de `LiveConsoleViewModel` **no cambia**: solo las
implementaciones de `DisplayOutputService` y `MediaPlaybackService`.

## Pasos

### 1. Pantalla externa
- Investiga con `DocumentationSearch` la forma actual (iPadOS 27) de proveer contenido a una pantalla externa no interactiva
  (rol de escena de pantalla externa, `UIWindowScene` / escenas de SwiftUI) y si la app debe declarar el rol en el `Info.plist`.
  Respeta que en iPadOS la pantalla externa puede estar en modo espejo o extendido (Stage Manager).
- `ProjectionStore` (`@Observable`, compartido por la app): `frame: ProjectionFrame`, `videoPlayer: AVPlayer?`.
- La escena externa muestra **solo** `ProjectionCanvas(frame)` a pantalla completa, negro, sin controles ni barra de estado, con el
  mismo fundido cruzado. Si hay video en el TV, `AVPlayerLayer` (envuelto en `UIViewRepresentable`) dentro del lienzo.
- `LiveDisplayOutputService`:
  - `connectedDisplay()`: nombre ("Pantalla externa" o el que exponga el sistema, por ejemplo el del receptor AirPlay) y resolución
    real (`"1920 × 1080"`) de la escena externa; `nil` si no hay.
  - `present(_:)` actualiza `ProjectionStore.frame`.
  - Emite cambios de conexión para que el chip de la barra superior pase entre "Sala principal · 1920 × 1080" y "Sin pantalla ·
    Conecta un TV" en vivo.
- Simulador: *I/O › External Displays* para probar.

### 2. Reproducción
- `LiveMediaPlaybackService` con `AVPlayer`:
  - Sesión de audio `.playback` (suena con el interruptor de silencio y la pantalla bloqueada) y activación al reproducir.
  - Música: reproduce el archivo local en el salón; el TV no cambia (spec §7.2).
  - Video: el mismo `AVPlayer` lo comparte `ProjectionStore.videoPlayer` para que la escena externa lo dibuje; la vista EN VIVO de la
    consola muestra el mismo reproductor reducido (sin controles).
  - `play`, `pause`, `resume`, `stop`, `seek`, `setLooping` reales. Fin del archivo: repetir o detener según la spec §7.4.
  - Publica el tiempo transcurrido y la duración reales (`addPeriodicTimeObserver` cada 0,5 s) para que el mini reproductor deje de
    simularlos: adapta `LiveConsoleViewModel.runPlaybackClock` para leer del servicio cuando el modo es live.
  - Una sola reproducción a la vez; presentar texto o imagen pausa un video en curso; la música sigue.
- Controles en la pantalla de bloqueo (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`): título y play/pausa.

## Criterios de aceptación

- Simulador con pantalla externa: letras, versículos, imágenes y videos se ven en ella sin interfaz; el chip de TV cambia al
  conectar y desconectar; la música suena y el mini reproductor muestra el avance real.
- `BuildProject` limpio; vistas previas siguen con los mocks.

## Desviaciones

_(Completar al cerrar la fase.)_
