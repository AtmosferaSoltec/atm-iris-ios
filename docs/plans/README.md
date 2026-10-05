# Planes de implementación · atm-iris-ios (consola iPad)

> **Para el agente del iPad.** Este es tu punto de partida. Trabajas en la **Mac**, solo en este
> repo, las fases en orden y sin detenerte entre ellas (reglas completas en
> [`00-fundamentos/plataforma.md`](00-fundamentos/plataforma.md) §4).
> La maqueta está terminada y aprobada: ahora se conecta a la API real, funciona sin conexión,
> proyecta de verdad en el TV y reproduce audio y video.

## Lee antes de empezar

1. [`00-fundamentos/plataforma.md`](00-fundamentos/plataforma.md): producto, arquitectura y reglas de trabajo.
2. [`../api-contract.md`](../api-contract.md): el contrato de la API. **La API se está construyendo a la vez que tú**:
   implementa contra el contrato aunque el endpoint todavía no exista. El login ya funciona en la API
   (`pnpm start:dev` en `../atm-iris-api`, cuenta `pastor@vidanueva.org` / `vidanueva123`); el resto llega durante tu trabajo.
3. [`../../IRIS_SPEC.md`](../../IRIS_SPEC.md): diseño, pantallas y reglas. Lo que ya existe no se rediseña.
4. [`../../IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) **§1 (reglas de trabajo, arquitectura y *gotchas*)**: sigue
   vigente. Sus fases ya están hechas. **Ignora** su indicación de detenerte tras cada fase: aquí trabajas de corrido.

## Herramientas y verificación

- Usa las herramientas de Xcode (`XcodeRead`, `XcodeWrite`, `BuildProject`, `RenderPreview`, `DocumentationSearch`…) como
  dice `IMPLEMENTATION_PLAN.md` §1.1. iOS 27 tiene APIs nuevas: **consulta la documentación** ante cualquier duda
  (pantalla externa, SwiftData, AVFoundation, Keychain).
- **Verificación de cada fase**: `BuildProject` sin errores ni warnings nuevos, y `RenderPreview` de cada vista que toques.
  Las pruebas (Swift Testing) se escriben y corren **solo en la fase 10**.

## Fases

| # | Fase | Estado |
|---|---|---|
| 00 | [Fundamentos](00-fundamentos/README.md): configuración, cliente HTTP, modelos del contrato, Keychain, modo de datos | [x] |
| 01 | [Login](01-login/README.md): acceso real, sesión que no vuelve a pedir contraseña, recuperación en 3 pasos | [x] |
| 02 | [Sincronización](02-sincronizacion/README.md): copia local (SwiftData), feed de cambios, cola de escrituras, conexión | [x] |
| 03 | [Cuenta y permisos](03-cuenta-y-permisos/README.md): cambio de iglesia, cerrar sesión, permisos en cada pantalla | [x] |
| 04 | [Iglesia](04-iglesia/README.md): módulos, personas y tipos de servicio sobre la copia local | [x] |
| 05 | [Canciones](05-canciones/README.md): biblioteca de letras real | [x] |
| 06 | [Multimedia](06-multimedia/README.md): caché de archivos, fondos personalizados, biblioteca real | [x] |
| 07 | [Biblia](07-biblia/README.md): RVR1909 completa sin conexión | [x] |
| 08 | [Tiempos](08-tiempos/README.md): guardar, ajustar y consultar registros | [x] |
| 09 | [TV y reproducción](09-tv-y-reproduccion/README.md): pantalla externa real, audio y video reales | [x] |
| 10 | [Calidad y entrega](10-calidad-y-entrega/README.md): pruebas, limpieza, documentación, reporte | [x] |

Marca cada casilla al terminar la fase y completa su sección *Desviaciones*.

## Reglas propias de este repo

- Arquitectura actual: vistas sin lógica, ViewModels `@Observable`, datos solo por protocolos inyectados desde
  `AppDependencies`. Las implementaciones reales se llaman `Live…` y conviven con los `Mock…` (que quedan para vistas
  previas y pruebas).
- **Nada de red en las vistas ni en los ViewModels**: los ViewModels hablan con los repositorios; los repositorios leen la
  copia local y escriben por la cola. Solo `Core/Networking`, `Core/Auth` y `Core/Sync` hablan con la API.
- Todo texto visible en español, como la spec; los mensajes de error de la API se muestran tal cual.
- Fechas, "hoy" y periodos en la **zona horaria de la iglesia** (`session.church.timezone`), no la del iPad.
