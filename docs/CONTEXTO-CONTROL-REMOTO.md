# Iris iPad · contexto del proyecto

Documento de traspaso para quien continúe el trabajo del iPad y los cambios que Iris Desktop necesita para
conectarse con él. Léelo completo antes de tocar código. Las decisiones del usuario están marcadas como **Decidido**;
lo demás son propuestas que debes validar y, si cambian algo importante, preguntar.

## 1. Qué es Iris

Iris es una aplicación de **escritorio** (Windows y macOS, Electron) para iglesias: la computadora maneja una segunda
pantalla (TV o proyector por HDMI) y proyecta letras, versículos, imágenes, videos y fondos, reproduce las pistas de
audio y lleva el tiempo de cada bloque del servicio. **Sin backend, sin cuentas, sin internet** (salvo comprobar
actualizaciones y reproducir un enlace de YouTube). Los datos viven en SQLite local y los archivos en una carpeta `Iris/`.

Repositorios (todos bajo `/Users/jmaldonado/Documents/Atmosfera/`):

| Carpeta | Qué es |
|---|---|
| `atm-iris-desktop` | La app de escritorio. Se publica con tags `vX.Y.Z` (GitHub Actions) en `https://iris.atmosferast.com/releases/`. **Lee su `AGENTS.md` y `docs/plans/README.md` primero.** |
| `atm-iris-ios` | La app de iPad (este repo). Hoy es una **maqueta**. |
| `atm-iris-web` | La landing pública (React). No interviene en el iPad. |
| `atm-iris-api`, `atm-iris-web-next`, `atm-iris-win` | Proyectos descartados. **No tocar ni portar código.** |

## 2. Qué será el iPad

**Un control remoto de la app de escritorio**, como el control de un televisor. **Decidido:**

- El iPad **no guarda ni gestiona** canciones, letras, archivos ni base de datos. Todo lo usa de la computadora.
- **No se agregan canciones ni elementos al servicio desde el iPad.** Eso se hace en la computadora. El iPad solo
  muestra el servicio, permite elegir un elemento y moverse por él.
- **Sin sesión guardada.** Cada vez que se abre la app, el iPad pide el **código de 6 dígitos** que muestra la app de
  escritorio (Configuración → «Vincular iPad»). No hay Keychain, ni "recordar", ni lista de iPads vinculados ni
  revocación. El código se escribe en un **teclado numérico propio de la app** (no el teclado del sistema).
  Sin búsqueda constante de equipos ni listas.
- Solo funciona dentro de la **misma red Wi-Fi**.
- No hay Android (no se ve necesario).
- Puede haber varios iPads vinculados a la misma computadora (idea, no decidida: permisos por iPad).

## 3. Qué hace el iPad (pantallas y comportamiento)

La maqueta en `iris/Mockup/` ya define el diseño; los datos son de ejemplo (`MockData.swift`). Lo decidido:

1. **Conectar** (`PairingScreen`), siempre al abrir: 6 casillas, teclado numérico propio y «Conectar».
2. **Control en vivo** (`RemoteScreen`), una sola pantalla en horizontal:
   - **Barra de tiempos arriba** (`TimerBar`), igual en espíritu a la de la computadora: bloque actual y responsable,
     reloj `transcurrido / previsto` y lo que queda, bloques (hecho / actual / pendientes) y el botón
     **«Siguiente: <bloque> →»**. No hay pausa del servicio (la computadora no la tiene).
   - **Servicio a la izquierda**: lista de elementos (canción, Biblia, video, imagen). Tocar uno lo selecciona.
   - **Diapositivas como cuadros** (`SlideGrid`): cuadros negros con texto blanco, 3 por fila, en cualquier orden.
     Tocar un cuadro lo proyecta de inmediato. La activa lleva borde y un punto «en pantalla». **No** hay botones
     anterior/siguiente de diapositiva (las canciones no siempre se cantan en orden).
   - **Barra de audio/video abajo** (`PlaybackBar`): posición, reproducir/pausar, volver al inicio, detener, repetir,
     volumen y «Limpiar pantalla». Aparece solo si el elemento tiene pista o video.
   - **Fondos** (`BackgroundsSheet`): elegir el fondo de la canción actual desde el iPad (las imágenes están en la
     computadora).
   - **Herramientas** (`ToolsSheet`): **Cronómetro/temporizador** en pantalla y **Sonidos**. El **texto** (tipografía)
     NO va en el iPad; se maneja en la computadora.
   - **Biblia** (`BibleSheet`): libro, capítulo y versículos como cuadros; «Enviar a la pantalla».
3. Desvincular desde la cabecera.

Preguntas de diseño abiertas: si el temporizador de la computadora es de cuenta regresiva o de otro tipo (igualar al
de escritorio); si el fondo debe poder fijarse también para todo el servicio; permisos por iPad.

## 4. Estado actual del proyecto iPad

- Se **eliminó toda la funcionalidad anterior** (cuentas, API, sincronización, proyección, reproducción). Queda
  `iris/DesignSystem` (tokens y componentes) y `iris/Mockup`. El historial de git conserva lo anterior.
- SwiftUI, iPad solamente, `IPHONEOS_DEPLOYMENT_TARGET = 27.0`, Xcode 27. Bundle `com.atm.iris`.
- Diseño solo horizontal (`IrisLandscapeCanvas` escala el lienzo 1100×640; iPadOS 27 ya no permite bloquear la
  orientación). Tema oscuro, espectro ámbar→coral→rosa, tipografía serif para títulos.
- Código en inglés, textos al usuario en español. `IRIS_SPEC.md` sirve como referencia de **diseño** (§3–5); sus
  secciones de pantallas, login, módulos y API ya no aplican.
- Ver la maqueta: abrir `iris.xcodeproj`, esquema `iris`. Argumentos de lanzamiento: `-connected` (salta la
  vinculación) y `-sheet bible|backgrounds|tools`.
- `irisTests` está vacío a propósito.

## 5. Lo que debe cambiar en Iris Desktop

Hoy **no existe nada** de esto en el escritorio. Hechos de su arquitectura que importan:

- Tres procesos y una regla: el *renderer* nunca toca Node, archivos ni la base de datos; solo usa `window.iris`
  (contrato tipado en `src/shared/ipc/contract.ts`, con zod). Los *handlers* son delgados y llaman a *services*; los
  *repositories* son lo único que escribe SQL (`node:sqlite`). Errores con `AppError` y mensajes en español.
- **El estado "en vivo" vive en el renderer** (`src/renderer/src/features/console/use-live-console.ts`): posición
  de la diapositiva en pantalla, reproducción de la pista (`Playback`), cuenta regresiva, volumen, pantalla limpia.
  El renderer empuja *frames* al proceso principal (`projection:push-frame`), que los muestra en la ventana de
  proyección. El servicio (plan) y los tiempos sí se persisten en main (`plan:*`, `timing-service.ts`).
- Una API de red nueva choca con la regla del proyecto «sin red salvo donde un plan lo diga»
  (`AGENTS.md` §11 y `docs/plans/00-foundations/platform.md`). **Hace falta un plan nuevo en `docs/plans/`**
  (p. ej. `18-remote-control/`) y la aprobación del usuario antes de implementarlo. No cambies una decisión de
  `platform.md` por tu cuenta: pregunta o registra una desviación.

### Piezas propuestas (a validar)

1. **Servidor remoto en el proceso principal** (`src/main/remote/`): escucha solo en la red local, WebSocket (más
   endpoint HTTP mínimo para vincular). Cada mensaje se valida con zod, igual que el IPC. Nunca expone rutas ni
   archivos: el iPad pide archivos (miniaturas de fondos) por id.
2. **Puente con el renderer de la consola**: como el estado en vivo está en el renderer, la opción más pequeña es que
   main reenvíe los comandos remotos a la ventana de consola (evento IPC), que los ejecute con las mismas funciones
   que usa la interfaz, y que el renderer devuelva *instantáneas de estado* a main para difundirlas a los iPads.
   Alternativa mayor: mover ese estado a main. Evalúa y justifica.
3. **Conexión por código, sin persistencia**: la app de escritorio muestra un código de 6 dígitos de un solo uso que
   caduca en pocos minutos (Configuración → «Vincular iPad»). Al aceptarlo emite un **token de sesión que solo vive en
   memoria** (en el iPad y en la computadora); al cerrar la app del iPad se pierde y se vuelve a pedir un código. Si la
   conexión se corta con la app abierta (Wi-Fi, iPad en reposo), reconectar solo con ese token en memoria, sin pedir
   código; si no se puede, volver a la pantalla del código. Sin lista de dispositivos ni revocación (el escritorio
   puede "desconectar iPads" de golpe, y todo se borra al cerrar Iris).
4. **Descubrimiento**: sin lista en el iPad. Como el código por sí solo no dice dónde está la computadora, propuesta:
   la computadora se anuncia por Bonjour (`_iris._tcp`) y el iPad la encuentra en silencio y prueba el código contra
   los equipos hallados (si hay varios con Iris abierto, el código identifica a cuál corresponde); respaldo: poder
   escribir la IP a mano en un enlace discreto de la pantalla del código.
   Windows pedirá permiso de firewall la primera vez: explicarlo en el onboarding/Configuración.
5. **Estado que recibe el iPad**: elementos del servicio (id, título, tipo, diapositivas con etiqueta y texto), elemento
   y diapositiva en pantalla, pantalla limpia, reproducción (posición, duración, reproduciendo, repetir, volumen),
   bloque actual, reloj y bloques del servicio, fondo actual y fondos disponibles (con miniatura), sonidos
   disponibles, cronómetro, estado de proyección.
6. **Comandos del iPad**: elegir elemento, proyectar diapositiva N, limpiar/mostrar, reproducir/pausar/detener/
   buscar posición/repetir/volumen, siguiente bloque, elegir fondo, iniciar/pausar/reiniciar cronómetro y mostrarlo,
   reproducir un sonido, buscar y proyectar un pasaje bíblico. **No** hay comandos para agregar/quitar elementos del
   servicio ni para editar canciones o tipografía.
7. **Seguridad**: solo red local; token de sesión obligatorio en todo mensaje; el código no sirve más de una vez y
   caduca; límite de intentos (el código es corto, así que bloquear tras unos fallos y generar otro); nada de rutas de archivos; versión del protocolo en el saludo para poder evolucionar las dos apps.
8. **Compatibilidad de versiones**: la app de escritorio se actualiza sola de forma obligatoria; el iPad no. El
   protocolo debe llevar versión y el iPad mostrar «actualiza Iris en la computadora» si no coinciden.

## 6. Formas de trabajo

- **Decidido por el usuario: no hacer commit ni push**; el usuario maneja git. En escritorio se publica con tags.
- Escritorio: antes de terminar una fase `pnpm check && pnpm format:check && pnpm build`, y `pnpm test:e2e` si toca
  interfaz o ventanas. Pruebas unitarias junto con la lógica. En una terminal de VS Code usa
  `env -u ELECTRON_RUN_AS_NODE pnpm dev`.
- iPad: compilar con
  `xcodebuild -project iris.xcodeproj -scheme iris -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`.
- Todo texto visible en español; código, comentarios y nombres en inglés (los comentarios explican el porqué).
- La documentación y la landing no mencionan precio ni licencia: no inventes.

## 7. Orden sugerido

1. Plan del escritorio (`docs/plans/18-remote-control/`): protocolo, vinculación, seguridad y puente con la consola;
   aprobarlo con el usuario.
2. Servidor remoto + vinculación + pantalla «Vincular iPad» en Configuración (con pruebas), probado con un cliente de
   prueba (sin iPad).
3. En el iPad: capa de red (descubrimiento, código, WebSocket, token en memoria) detrás de protocolos Swift que la
   maqueta ya puede consumir; sustituir `MockData` por el estado real pantalla por pantalla.
4. Cronómetro, sonidos, fondos y Biblia.
5. TestFlight con la cuenta de desarrollador del usuario.


## 8. Estado de la implementación (actualizado)

**Hecho y probado de punta a punta** (app de escritorio real + iPad en el simulador, descubrimiento por Bonjour):

- **Escritorio** (`atm-iris-desktop`, fase `docs/plans/18-remote-control/`): servidor WebSocket (`src/main/remote/`),
  vinculación por código (`pairing-gate.ts`), anuncio Bonjour, panel «Control desde iPad» en Ajustes (apagado por
  defecto), puente con la consola (`src/renderer/src/features/remote/`). Protocolo en `src/shared/remote/protocol.ts`.
  Pruebas unitarias y `e2e/remote.spec.ts`.
- **iPad** (`iris/Remote/`, `iris/Screens/`): `RemoteProtocol` (espejo del protocolo), `RemoteLink` (WebSocket con
  Network.framework), `RemoteClient` (descubrimiento, código, reconexión con token en memoria, estado). Las pantallas
  ya leen el estado real y mandan comandos. `DemoState` solo alimenta previews y `-demo`.
- **Desde 1.2.0 (escritorio) / build 7 (iPad)**: Biblia (`BibleSheet`, libros y versículos por petición/respuesta;
  selector de versión solo si hay más de una), multimedia de la biblioteca (`MediaSheet`), elegir el servicio antes de
  empezar, quién dirige cada bloque (`LeaderSheet`), «Agregar bloque» solo para ese servicio (`AddBlockSheet`) y
  terminar el servicio. La Biblia y la multimedia se presentan una vez: nunca entran al servicio.
- **Desde 1.3.0 (escritorio)**: miniaturas de fondos, imágenes y videos (petición `thumbnail`, una a la vez, solo en
  memoria: `RemoteClient.wantThumbnail`, `RemoteThumbnail`), texto del cronómetro y «Desconectar» con confirmación.
- Argumentos de lanzamiento de depuración (solo `DEBUG`): `-demo`, `-pair 123456 [-address 192.168.1.20] [-show N]
  [-exercise]`, `-sheet bible|media|backgrounds|tools|block`.

**Pendiente**

- Probar en un iPad físico y en Windows (firewall): el permiso de «red local» de iOS aparece la primera vez.
- Si el protocolo cambia: subir `PROTOCOL_VERSION` en ambos lados.
