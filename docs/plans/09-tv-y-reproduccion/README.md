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

- No hubo `DocumentationSearch` en esta sesión. Se usó el mecanismo documentado desde iPadOS 16: el delegado de la app
  devuelve, para el rol `windowExternalDisplayNonInteractive`, una `UISceneConfiguration` con
  `ExternalDisplaySceneDelegate` (ventana con `UIHostingController`); los demás roles quedan para SwiftUI.
  **Reemplazado el 2026-10-07**: desde **iOS 27** el sistema ya no conecta solo la escena
  `windowExternalDisplayNonInteractive` (ni por el `Info.plist` ni por el delegado de la app): si la app no registra
  un *scene accessory*, **replica el iPad** en el TV con todos los controles. Ahora la vista raíz registra
  `ExternalNonInteractiveAccessory` con `.sceneAccessory` (`projectionOnExternalDisplay()` en
  `Core/Display/ExternalDisplayScene.swift`) y el TV muestra solo `ExternalProjectionView`. Se quitaron
  `ExternalDisplaySceneDelegate` y la rama del rol en `IrisAppDelegate`. El chip de TV se enciende cuando la
  proyección se dibuja en el TV y se apaga con `onAvailabilityChange(false)` o al desaparecer. Registros de
  diagnóstico en la categoría `TV` de `com.atm.iris`. Documentación: *Presenting content on a connected display*
  (UIKit) y `ExternalNonInteractiveAccessory` (SwiftUI).
- El nombre de la pantalla es el del receptor AirPlay cuando la ruta de audio lo informa; si no, "Pantalla externa".
- `ProjectionStore.shared` es un singleton porque UIKit crea la escena externa por su cuenta.
- El video se dibuja dentro de `ProjectionCanvas` mediante el valor de entorno `projectionVideoPlayer` (en el TV y en la
  vista EN VIVO de la consola); sin reproductor, el lienzo conserva el marcador de las vistas previas.
- `MediaPlaybackService.play` recibe la URL local, el tipo y el título, y el protocolo gana `reportsProgress` y
  `progressUpdates()`; `runPlaybackClock` lee del servicio en modo live y simula con el mock.
- `DisplayOutputService` gana `displayUpdates()` y `videoPlayer`; Inicio y la consola siguen la conexión en vivo.
- `UIBackgroundModes = audio` en `Config/Info.plist` para que la música siga con la pantalla bloqueada.
- No se probó en el simulador con *I/O › External Displays* (no hay forma de manejar ese menú desde esta sesión):
  queda para la verificación manual de la fase 10 / revisor.
- **Pantalla encendida**: mientras la consola está abierta (`LiveConsoleScreen`) el iPad no se bloquea
  (`isIdleTimerDisabled`); si se bloquea, el TV se apaga con él.

- **Proyección: tipografía, tamaño y fondo por defecto (2026-10-07)**: contrato §6, `Church.projection`.
  `ProjectionSettings` (typo iOS) / `ProjectionSettingsDTO` viajan `fontFamily` (una de 10 claves, nunca un nombre
  de fuente — ver la tabla en `src/modules/church/projection-fonts.ts` de la API), `fontSizePt` (40–200, referido a
  una pantalla de 1920 de ancho; cada superficie lo escala por `ancho_real / 1920`) y `defaultBackgroundId`
  (un fondo de la biblioteca, o `null` = negro). Pantalla en Módulos › Proyección (`ProjectionSettingsViewModel` /
  `ProjectionSettingsView`), con vista previa en vivo.
- **Un servicio nuevo ya no abre con el primer degradado**: antes `selectedBackgroundID` tomaba
  `backgrounds.first` (la "Aurora" morada) apenas se cargaba la consola. Ahora toma el `defaultBackgroundId`
  configurado en Proyección, o `nil` (negro puro) si no hay ninguno — nunca una elección por casualidad.
  El selector de fondos de la consola gana una opción explícita "Ninguno" para volver a negro a mitad de un
  servicio (antes no había forma de deshacer un fondo elegido).
- **La tipografía es la misma en consola y TV**: `ProjectionCanvas` recibe `typography: ProjectionSettings` como
  parámetro (no una lectura oculta de un singleton) en sus 5 usos — hilo de vista, no de ambiente, salvo para la
  pantalla externa: como esa es una ventana UIKit aparte sin la jerarquía de vistas de la consola,
  `LiveConsoleViewModel` espeja la tipografía a `ProjectionStore` vía `DisplayOutputService.setTypography(_:)`
  (igual que ya hacía con `present(_:)` para el cuadro). El fondo no necesita ese espejo: ya viaja dentro de cada
  `ProjectionFrame`.
