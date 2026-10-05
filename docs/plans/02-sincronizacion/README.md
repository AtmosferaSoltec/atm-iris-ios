# 02 · Sincronización: copia local, feed y cola de escrituras

## Objetivo

Contrato §12. El iPad trabaja **sin conexión**: todo lo que muestra sale de una copia local de la
iglesia, que se pone al día con `GET /sync/changes`, y todo lo que escribe va primero a la copia
local y a una **cola** (outbox) que se envía en orden cuando hay red.

## Dependencias

Fases 00 y 01.

## Diseño

```
Repositorios Live ──lee──▶ LocalStore (SwiftData)  ◀──aplica páginas── SyncEngine ◀── GET /sync/changes
        │                         ▲                                           │
        └─escribe─▶ LocalStore + Outbox ──────────── flush en orden ──────────┘──▶ POST/PUT/PATCH/DELETE
```

### 1. `LocalStore` (`Core/Persistence/`)
- SwiftData con un `ModelContainer` propio en `Application Support/Store/` (no en iCloud).
- `@Model` por entidad: `StoredChurch` (nombre, zona, módulos, almacenamiento), `StoredPerson`, `StoredServiceType` (bloques
  como `Codable` embebido en orden), `StoredSong` (secciones embebidas), `StoredMedia`, `StoredServiceRecord` (bloques
  embebidos), `SyncState` (iglesia, cursor, fecha de la última sincronización correcta), `OutboxOperation`.
  Todas con `churchID` y el `id` del contrato como `@Attribute(.unique)`.
- Acceso desde un `@ModelActor actor LocalStore` con métodos de dominio (`people()`, `upsert(_ people: [PersonDTO])`,
  `delete(personIDs:)`, `apply(_ page: SyncPageDTO)` en **una** transacción, `clear()`), que devuelven modelos de `Core/Models`
  (nunca objetos `@Model` hacia los ViewModels).
- Notificación de cambios: `LocalStore.changes: AsyncStream<StoreChange>` (`.people`, `.serviceTypes`, …) para que los
  repositorios avisen a los ViewModels abiertos y estos recarguen en silencio.

### 2. `SyncEngine` (`Core/Sync/`)
`actor` con:
- `syncNow(reason:)`: si hay red y sesión, primero **vacía la cola** y luego pide páginas desde el cursor guardado hasta
  `hasMore == false`, aplicando cada una en una transacción y guardando el cursor tras cada página. Una sola ejecución a la vez
  (si llega otra petición, se encadena una vez más al terminar).
- Disparadores (contrato §12): al entrar con sesión, al volver al Inicio, cada 5 min mientras el Inicio está visible, al
  recuperar la conexión, y el botón "Actualizar". **Pausado mientras hay un servicio en curso** en la consola (`suspend()` /
  `resume()` desde `LiveConsoleViewModel`).
- Estado observable para la interfaz: `SyncStatus { idle(lastSync: Date?), syncing, offline(pending: Int), failed(message) }`.

### 3. Cola de escrituras (`Core/Sync/Outbox.swift`)
- `OutboxOperation`: `id`, orden (secuencia local creciente), método, ruta, cuerpo JSON, `createdAt`, intentos, último error.
- `enqueue(_:)` siempre después de aplicar el cambio en la copia local (escritura optimista).
- `flush()`: envía en orden, una a la vez. Resultado por operación:
  - 2xx → se borra de la cola.
  - Red / 5xx / 429 → se detiene y se reintenta con espera exponencial (5 s, 15 s, 60 s, luego cada 5 min).
  - 401 → lo resuelve `AuthSessionManager`; si la sesión murió, la cola queda guardada para el próximo inicio de sesión de la
    **misma** iglesia.
  - Otro 4xx (validación, permiso, duplicado) → se descarta, se guarda el mensaje para avisar ("No se pudo guardar «…»: {mensaje}")
    y se fuerza una sincronización completa de ese tipo para volver a la verdad del servidor.
- Las operaciones usan siempre los endpoints idempotentes del contrato (§2): crear con `id` propio, `PUT` para tipos de servicio,
  registros y módulos.

### 4. Conexión
- `ConnectivityMonitor` con `NWPathMonitor` (`AsyncStream<Bool>`). Al pasar a "con red": `syncNow(.reconnected)`.

### 5. Interfaz
- Barra superior (Inicio y pantallas de iglesia): indicador discreto junto al estado del TV:
  "Actualizado hace 2 min" · "Actualizando…" · "Sin conexión · 3 cambios pendientes" (ámbar) · error con "Reintentar".
  Clic → popover con el detalle y el botón "Actualizar ahora".
- Primera sincronización tras iniciar sesión: pantalla de carga sobre el Inicio "Preparando tu iglesia…" con progreso por
  páginas; si no hay red y no hay copia, estado vacío "Necesitas conexión para descargar tu iglesia la primera vez." + "Reintentar".
- Cerrar sesión o cambiar de iglesia: si la cola tiene operaciones, confirmar "Hay {N} cambios sin enviar. Si sigues, se perderán."
  Luego `LocalStore.clear()` y limpieza de la cola.

## Criterios de aceptación

- Con la API corriendo (si ya tiene `/sync/changes`; si no, deja la verificación para la fase 10): primera sincronización llena
  la copia; sin red, la app abre y muestra los datos; una persona agregada sin red llega al servidor al reconectar.
- `BuildProject` limpio.

## Desviaciones

- La copia usa **un solo** `@Model` genérico, `StoredEntity` (clase, id, iglesia, clave de orden y el JSON del DTO del
  contrato), en lugar de un `@Model` por entidad. Bloques y secciones quedan embebidos en ese JSON. `SyncState` y
  `OutboxOperation` sí son modelos propios. `LocalStore` devuelve DTO y los repositorios los convierten a `Core/Models`.
- `SyncEngine` es una clase `@Observable` en el actor principal (no un `actor`): su estado alimenta la interfaz y el trabajo
  pesado ocurre en los actores `APIClient` y `LocalStore`. `Outbox` y `ConnectivityMonitor` siguen el mismo criterio.
- Si después de vaciar la cola quedan operaciones (sin red o error 5xx), **no** se piden páginas: así una edición local que
  aún no llega al API no se pisa con la versión anterior del servidor.
- "Sincronización completa de ese tipo" tras un rechazo 4xx: se vuelve a leer la lista del tipo (`GET /people`,
  `/service-types`, `/service-records` paginado, `/church`) y se reemplazan esas filas en la copia.
- La pausa durante el servicio la aplica `SignedInNavigator` al entrar y salir de la consola (`suspend()`/`resume()`).
- Los protocolos de repositorio ganan `changes() -> AsyncStream<Void>` (los mocks no emiten nada); los ViewModels abiertos
  recargan en silencio con `observeChanges()`.
- Al expirar la sesión (refresh 401) la copia y la cola se conservan; si la siguiente sesión es de otra iglesia,
  `LocalStore.prepare(for:)` las borra.
- `/sync/changes` todavía no existe en la API: la verificación con datos reales queda para la fase 10.
