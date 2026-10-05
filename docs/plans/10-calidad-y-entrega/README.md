# 10 · Calidad y entrega

## Objetivo

Cerrar el iPad: pruebas de lo importante, limpieza, documentación y el reporte final.

## 1. Integración con la API (si ya está lista)

Con `pnpm start:dev` en `../atm-iris-api` y su seed (`pastor@vidanueva.org`, `operador@vidanueva.org` / `vidanueva123`):
recorre login, primera sincronización, canciones y multimedia de la web, Biblia, un servicio con tiempos sin conexión y
reconexión, cambio de iglesia y roles. Corrige **tu lado**; lo del API anótalo para el revisor. Si la API no está completa,
déjalo como pendiente en el reporte.

## 2. Pruebas (Swift Testing, `irisTests`)

Mantén las que existen y agrega, al menos:
- Decodificación de los ejemplos del contrato (`AuthResult`, `SyncPage` con cambios y borrados, `ServiceType`, `ServiceRecord`,
  error con `errors`), fechas con milisegundos y enums desconocidos.
- `AuthSessionManager`: refresh antes de vencer, single flight con peticiones concurrentes, 401 en el refresh cierra sesión, error
  de red no la cierra (con un `URLProtocol` falso).
- `SyncEngine`: aplicar páginas en orden, `hasMore`, cursor persistido, borrados, pausa durante el servicio.
- `Outbox`: orden, reintento con red caída, descarte con 4xx, idempotencia de ids.
- `LivePeopleRepository` / `LiveServiceTypeRepository` sobre un `LocalStore` en memoria (duplicados por `nameKey`, borrar persona
  limpia plantillas).
- `TimeStatistics` con zona horaria de la iglesia (un registro a las 23:30 del último día del mes en Lima cae en ese mes).
- `nameKey` con espacios internos (contrato §2).
- Permisos: matriz por rol de las acciones visibles en los ViewModels.

Todas en verde, y `BuildProject` sin warnings nuevos.

## 3. Limpieza

- `AppDependencies.live` por defecto; mocks solo para vistas previas, pruebas y `-IrisDataMode mock`.
- Elimina lo que quedó sin uso de la maqueta (por ejemplo `MockServicePlanRepository` si solo lo usaban vistas previas que ya no existen).
- Sin `print` ni `TODO` sin explicar.

## 4. Documentación

- `README.md` del repo (créalo): qué es, requisitos (Xcode 27, iPadOS 27), cómo apuntar a la API (xcconfig, iPad físico con la IP
  de la Mac), modo mock, arquitectura (`Core/Networking`, `Auth`, `Persistence`, `Sync`, `Media`, `Bible`), pruebas.
- `IRIS_SPEC.md`: agrega una sección corta "Estado: conectado a la API" que reemplace la nota de "maqueta" del inicio, con los
  cambios de comportamiento (sesión permanente, sin conexión, recuperación por código, permisos). **No** reescribas el resto.

## 5. Reporte

Entrega el reporte de `00-fundamentos/plataforma.md` §6 y pregunta al usuario si puede dar el repo por terminado.

## Desviaciones

- **Integración**: la API local ya expone todos los endpoints que usa el iPad. Todos los payloads reales (`/church`,
  `/people`, `/service-types`, `/songs`, `/sync/changes`, `/media`, `/bible/translations`, `/service-records`) se
  decodifican con los DTO. `LiveAPIIntegrationTests` recorre contra la API real el login (y el error
  `INVALID_CREDENTIALS`), la primera sincronización, una persona creada local → cola → API (una sola vez) y su
  borrado, la descarga de la Biblia con Juan 3:16 y el cierre de sesión. Esas pruebas se saltan solas si la API no
  responde en `localhost:3020`. Hacen 5 logins: con el límite de 5/min de `sign-in`, correr la suite dos veces
  seguidas puede dar 429.
- No se recorrieron a mano en el simulador la interfaz completa, la pantalla externa (*I/O › External Displays*),
  el audio, el cambio de iglesia (la cuenta de desarrollo tiene una sola) ni el rol `operator` con su cuenta: quedan
  para el revisor.
- **Pruebas**: 114 casos en verde (Swift Testing). Las nuevas cubren contrato, `AuthSessionManager`, `SyncEngine`,
  `Outbox`, repositorios live, zona horaria, permisos e integración. El servidor falso es un `URLProtocol` con un host
  por prueba, así las pruebas pueden correr en paralelo.
- **Limpieza**: `.live` ya no usa ningún mock. `MockServicePlanRepository` queda solo para las vistas previas de la
  consola; en live, `EmptyServicePlanRepository` (el servicio empieza vacío). `MockShowcaseContentProvider` pasó a ser
  `StaticShowcaseContentProvider` (textos fijos de la pantalla de acceso). No quedan `print` ni `TODO`.
- Corrección encontrada por las pruebas: `JSONCoding.string(from:)` redondea al milisegundo (antes `.022` podía salir
  como `.021`).
- Las vistas previas compilan, pero no se renderizaron: no hubo herramienta `RenderPreview` en esta sesión.
