# 08 · Tiempos

## Objetivo

Contrato §14. Los registros del cronómetro llegan al servidor (aunque el servicio termine sin
conexión), la pantalla Tiempos lee los de toda la iglesia (de cualquier consola) y los ajustes se
envían con permiso.

## Dependencias

Fases 02, 03 y 04.

## Pasos

1. `LiveTimeRecordRepository`:
   - `records()` desde la copia local (más reciente primero).
   - `save(_:)`: local + `PUT /service-records/:id` en la cola. El id lo genera el `BlockTimer` (UUID) — verifica que sea estable
     entre reintentos ("Reintentar" de la consola no debe crear otro id).
   - Ajustes: `adjust(recordID, blockID, actualSeconds:)` y `changeLeader(recordID, blockID, personID:)` → local (estado `adjusted`,
     `personName` actual) + `PATCH /service-records/:id/blocks/:blockId`. `delete` → local + `DELETE`.
2. `BlockTimer.record(...)` arma `ServiceRecordInput` con `serviceTypeName` (copia del nombre) y bloques con `status`
   `completed`/`skipped` y `personName` del momento (spec §7.9).
3. "Guardar en la plantilla" al terminar (con permiso `serviceTypes.manage`, fase 03): `ServiceTypeRepository.save` (va por la cola).
   Sin permiso, solo "Solo hoy".
4. Consola: "No pudimos guardar los tiempos" ya **no** depende de la red: guardar en la copia local + cola casi nunca falla. El
   estado "Terminado" muestra, si la cola tiene ese registro pendiente, "Se enviará cuando haya conexión" (ámbar) en lugar de error.
5. `TimeStatistics` y `TimesViewModel`: periodos por mes calendario en la **zona de la iglesia** (`Calendar.church`), incluido
   "Elegir mes…". `now` sigue inyectado.
6. Nombres: persona borrada → `personName` guardado o "Persona eliminada"; tipo borrado → `serviceTypeName` guardado.

## Criterios de aceptación

- Un servicio terminado sin red aparece en la web al reconectar, una sola vez.
- Un `operator` no ve los ajustes.
- `BuildProject` limpio; vistas previas sin cambios.

## Desviaciones

_(Completar al cerrar la fase.)_
