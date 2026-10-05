# Iris · consola de iPad

Consola en vivo de **Iris** para iPad: proyecta en el TV de la iglesia letras, versículos, imágenes y videos, reproduce
música y mide el tiempo de cada bloque del servicio. Funciona **sin conexión** sobre una copia local de la iglesia que se
sincroniza con la API (`atm-iris-api`). Diseño y reglas: [`IRIS_SPEC.md`](IRIS_SPEC.md). Contrato: [`docs/api-contract.md`](docs/api-contract.md).
Planes de implementación: [`docs/plans/README.md`](docs/plans/README.md).

## Requisitos

- Xcode 27 y el simulador de iPadOS 27 (la app es solo iPad, `IPHONEOS_DEPLOYMENT_TARGET = 27.0`).
- La API corriendo en la Mac: `pnpm start:dev` en `../atm-iris-api` (puerto 3020). Cuenta de desarrollo:
  `pastor@vidanueva.org` / `vidanueva123`.

## Cómo correrlo

```sh
open iris.xcodeproj        # esquema "iris", destino: un iPad con iPadOS 27 → Run
# o desde la terminal:
xcodebuild -project iris.xcodeproj -scheme iris \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=27.0' build
```

### A qué API apunta

`Config/Debug.xcconfig` define `IRIS_API_BASE_URL` (por defecto `http://localhost:3020/api/v1`, válido para el
simulador). El valor llega al `Info.plist` como `IrisAPIBaseURL` y lo lee `AppConfig`. En un **iPad físico**, usa la IP
de la Mac en la red local:

```
IRIS_API_BASE_URL = http:/$()/192.168.1.20:3020/api/v1
```

(`/$()/` evita que el xcconfig lea `//` como comentario). `NSAllowsLocalNetworking` permite `http` solo en la red local.
`Release.xcconfig` queda vacío hasta que exista un servidor de producción.

### Modo de datos de prueba

En *Edit Scheme › Run › Arguments* activa `-IrisDataMode mock`: la app usa los mocks en memoria (sin red ni copia
local). Las vistas previas siempre usan los mocks.

## Arquitectura

```
App/               Composición (AppDependencies .live / .mock), RootView, SessionStore, SessionContext, navegación
Core/Config        AppConfig y DataMode
Core/Networking    APIClient (actor), APIRequest, APIError, DTO del contrato y su mapeo a Core/Models
Core/Auth          AuthSessionManager (tokens, refresh single-flight), Keychain, LiveAuthService
Core/Persistence   LocalStore (SwiftData, @ModelActor): copia local, estado de sincronización y cola de escrituras
Core/Sync          SyncEngine (GET /sync/changes), Outbox, ConnectivityMonitor, ChurchDataChanges
Core/Services      Protocolos de repositorio; Live… sobre la copia local; Mocks/ para vistas previas y pruebas
Core/Media         MediaCache (descarga en segundo plano), MediaDownloader, miniaturas de video
Core/Bible         BibleStore: RVR1909 descargada una vez y leída sin conexión
Core/Display       ProjectionStore y la escena de la pantalla externa
Core/Playback      LiveMediaPlaybackService (AVPlayer, sesión de audio, pantalla de bloqueo)
Features/          Vistas sin lógica + ViewModels @Observable
DesignSystem/      Tokens y componentes Iris*
```

Reglas: las vistas no tienen lógica; los ViewModels hablan con repositorios inyectados; solo `Core/Networking`,
`Core/Auth` y `Core/Sync` (y las descargas de `Core/Media`/`Core/Bible`) hablan con la API. Los repositorios leen la
copia local y escriben primero en ella y luego en la cola, que se envía en orden con endpoints idempotentes.
Fechas, "hoy" y periodos van en la zona horaria de la iglesia (`Calendar.church`).

## Pruebas

Swift Testing, target `irisTests`:

```sh
xcodebuild -project iris.xcodeproj -scheme iris \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=27.0' test
```

Cubren la decodificación del contrato, el ciclo de tokens (con un `URLProtocol` falso, `irisTests/StubServer.swift`),
la sincronización, la cola, los repositorios sobre una copia en memoria, la zona horaria de la iglesia, los permisos por
rol y la lógica de las pantallas (cronómetro, Tiempos, Inicio, Módulos, Personas, Servicios).
