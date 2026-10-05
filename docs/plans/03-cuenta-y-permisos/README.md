# 03 · Cuenta y permisos

## Objetivo

Que el iPad respete los roles (contrato §3), permita cambiar de iglesia y cerrar sesión en todos los
dispositivos. La gestión del equipo (invitar, roles) **se hace en la web**; el iPad no la replica.

## Dependencias

Fases 01 y 02.

## Pasos

### 1. Menú de la cuenta (avatar de la barra superior)
- Encabezado: nombre de la persona, correo, iglesia actual y su rol ("Dueño", "Administrador", "Operador").
- "Cambiar de iglesia" (solo si `churches.count > 1`): submenú con las iglesias; elegir otra → confirmación de cola pendiente
  (fase 02) → `switchChurch` → limpiar copia local → primera sincronización de la nueva iglesia → Inicio.
- "Cerrar sesión" y "Cerrar sesión en todos los dispositivos" (destructivo, confirmación "Se cerrará la sesión en la web, el iPad y
  Windows. Tendrás que volver a iniciar sesión en cada uno.").
- Pie: "El equipo se administra desde la web."

### 2. Permisos en las pantallas
Usa `session.can(_:)`. Sin el permiso la acción **no aparece** (salvo donde se indica):

| Pantalla | Permiso | Sin permiso |
|---|---|---|
| Módulos | `modules.manage` | Interruptores deshabilitados + nota "Solo un administrador puede cambiar los módulos." |
| Servicios (lista y editor) | `serviceTypes.manage` | Sin "Nuevo servicio"; la tarjeta abre el editor en solo lectura |
| Personas | `people.manage` | (los tres roles lo tienen; deja la verificación igual) |
| Consola · "Guardar en la plantilla" | `serviceTypes.manage` | La alerta de cambios solo ofrece "Solo hoy" |
| Tiempos · ajustar, cambiar responsable, eliminar | `records.manage` | Sin menú "•••" ni "Eliminar registro" |
| Consola · terminar servicio y guardar tiempos | `records.write` | (los tres roles lo tienen) |

- Si la API responde `403` a una operación de la cola (rol cambiado desde la web), aplica la regla de la fase 02 (descartar y avisar)
  y refresca la sesión (`GET /auth/me`) para actualizar los permisos.
- Refresca la sesión (`/auth/me`) en cada sincronización disparada al volver al Inicio, para que un cambio de rol hecho en la web
  se note sin cerrar sesión.

## Criterios de aceptación

- Vistas previas de cada pantalla con un `UserSession` de cada rol (`.preview(role:)`).
- `BuildProject` limpio.

## Desviaciones

- Los permisos se leen de un `SessionContext` observable compartido por las pantallas: un cambio de rol (refresh o
  `GET /auth/me`) se aplica sin reconstruirlas, para no perder un servicio en curso. Solo el cambio de iglesia reconstruye.
- Cambiar de iglesia no borra la copia antes de `switch-church`: si el API falla se conserva todo. La copia anterior se
  borra cuando la nueva iglesia arranca (`LocalStore.prepare(for:)`).
- Nombre, correo, iglesia y rol del encabezado del menú son botones deshabilitados (un `Menu` no admite otro contenido).
- El cronómetro de bloques solo aparece con `records.write` (sin él no se podría guardar el registro).
- Vistas previas por rol: Módulos, Servicios y Tiempos tienen una de `operator`. Se compilaron; no hubo herramienta para
  renderizarlas en esta sesión.
