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

_(Completar al cerrar la fase.)_
