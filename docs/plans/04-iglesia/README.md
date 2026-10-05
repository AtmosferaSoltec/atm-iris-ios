# 04 · Iglesia: módulos, personas y tipos de servicio

## Objetivo

Que Módulos, Personas, Servicios e Inicio funcionen con datos reales de la copia local, escribiendo
por la cola. Contrato §6, §8, §9.

## Dependencias

Fases 02 y 03.

## Pasos

1. `LiveModuleSettingsRepository`: lee `StoredChurch.modules`; `save` aplica local + `PUT /church/modules` en la cola.
2. `LivePeopleRepository`:
   - `people()` desde la copia (orden alfabético en español; `blockCount` viene del servidor).
   - `add(name:)`: valida duplicado local con `nameKey`; crea con **id propio** (UUID) local + `POST /people { id, name }`.
   - `rename`, `delete`: local + `PATCH` / `DELETE`. Al borrar, aplica también localmente la regla del contrato (quitar
     `defaultPersonID` de las plantillas) para que la pantalla quede coherente antes de sincronizar.
3. `LiveServiceTypeRepository`: `serviceTypes()` desde la copia; `save` → local + `PUT /service-types/:id` (sirve para crear y
   editar); `delete` → local + `DELETE`. Con el módulo de tiempo apagado, el editor reenvía los bloques existentes intactos.
4. Errores de duplicado que el servidor detecte después (otra persona creó el mismo nombre desde la web): los maneja la cola
   (fase 02) avisando y resincronizando.
5. `HomeViewModel`: la sugerencia del servicio de hoy y la fecha del saludo usan el `Calendar` de la iglesia. Recarga en silencio
   cuando `LocalStore.changes` avisa.
6. `ModulesViewModel`, `PeopleViewModel`, `ServiceTypesViewModel` y su editor: sin cambios de interfaz; solo el repositorio
   cambia y se suscriben a `LocalStore.changes`.

## Criterios de aceptación

- En modo live, con la copia sincronizada: crear, renombrar y borrar personas y servicios; apagar un módulo y ver su efecto
  (spec §7.8) en el Inicio y en la consola.
- `BuildProject` limpio; vistas previas sin cambios.

## Desviaciones

- Los repositorios comparten `LiveChurchData` (copia local + cola + aviso de cambios). Cada escritura: copia local →
  cola → `sync.flushSoon()`.
- `LiveModuleSettingsRepository.save` también actualiza `StoredChurch` localmente; si la copia aún no tiene la iglesia
  (primera sincronización pendiente) solo encola el `PUT`.
- `LivePeopleRepository.add` rechaza duplicados por *nameKey* con `LocalWriteError` (además de la validación del
  ViewModel), y Personas muestra el mensaje del repositorio en vez del genérico.
- Personas sigue contando bloques con los registros locales (no con `blockCount`), lo que da el mismo número sin conexión.
- `LiveTimeRecordRepository` se hizo aquí junto a los demás; su comportamiento es el de la fase 08.
