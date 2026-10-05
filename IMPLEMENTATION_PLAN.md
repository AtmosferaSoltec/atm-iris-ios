# Iris (iPad) — Plan de implementación de las pantallas pendientes

> **Para el agente que implementa.** Este documento es tu guía completa. Otro agente (el revisor) revisará cada fase al terminarla.
> Lee primero `IRIS_SPEC.md` (diseño, tokens, componentes, reglas) y luego este archivo.
> **Trabaja una fase a la vez.** Al terminar cada fase: compila, renderiza las vistas previas, y **detente** para que el revisor la apruebe antes de seguir.

---

## 0. Contexto rápido

- App SwiftUI **solo iPad**, iOS 27, Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `MemberImportVisibility` activo.
- Proyecto Xcode: `iris.xcodeproj`, target `iris`. Carpeta de fuentes: `iris/iris/…` (rutas del navegador de Xcode).
- **Maqueta**: sin backend. Todo dato pasa por **protocolos** con **mocks** en `Core/Services/Mocks/`.
- Código en **inglés**; todo texto visible en **español**.
- Diseño: oscuro, "luz a través de un vitral". **No inventes estilos**: usa solo tokens y componentes existentes (ver §2).

### Pantallas ya hechas y aprobadas (NO cambiar salvo lo que pida este plan)
Acceso (login/registro/recuperación), Inicio, Consola en vivo, Biblia, Agregar al servicio, selector de fondos, mini reproductor.

### Estructura actual
```
App/            AppDependencies, RootView, SessionStore, SignedInRoot (SignedInNavigator)
Core/Models/    UserSession, ServicePlan, ProjectionFrame, Bible, Library, Church, ShowcaseItem
Core/Services/  AuthService, ServicePlanRepository (+BackgroundRepository, DisplayOutputService),
                BibleRepository, LibraryRepository, MediaPlaybackService, ChurchRepositories, Mocks/
DesignSystem/   Tokens/ (IrisColor, IrisTypography, IrisLayout) · Components/ (Iris*)
Shared/         Projection/ProjectionCanvas · Formatting/IrisDurationFormat
Features/       Auth/ · Home/ · LiveConsole/ · Bible/ · AddToService/
```

---

## 1. Reglas de trabajo (obligatorias)

### 1.1 Herramientas
- Usa las herramientas de Xcode: `XcodeRead`, `XcodeWrite`, `XcodeGrep`, `XcodeGlob`, `XcodeMakeDir` (**crea carpetas de un nivel a la vez**), `BuildProject`, `RenderPreview`, `XcodeRefreshCodeIssuesInFile`, `RunProject`.
- Verifica cada fase con `BuildProject` **sin errores ni warnings nuevos** y `RenderPreview` de cada vista nueva (horizontal y vertical cuando aplique).
- Consulta `DocumentationSearch` ante cualquier API dudosa (iOS 27 tiene APIs nuevas).

### 1.2 Arquitectura
- **Vistas sin lógica**: solo pintan estado y llaman intenciones del ViewModel.
- **ViewModels** `@Observable final class`, propiedades de estado `private(set)` salvo las que se enlazan con `$`.
- **Modelos** en `Core/Models` como `nonisolated struct … : Identifiable, Hashable, Sendable`. **Declara `Hashable`/`Equatable` en el mismo archivo del tipo** (la síntesis en una extensión de otro archivo no compila).
- **Datos** solo vía protocolos (`any XRepository`) inyectados desde `AppDependencies`.
- Lógica de cálculo pura (estadísticas, cronómetro) en **structs puros testeables**, no en las vistas.
- Cada ViewModel con carga async debe exponer un método **síncrono `apply(...)`** que instala los datos (lo usan `load()` y las vistas previas) y un `static var preview` ya cargado. Las vistas previas que dependen de `.task` salen en estado "cargando"; por eso existe `apply`.

### 1.3 Gotchas conocidos (ya nos pasaron)
1. **No pases referencias a métodos como closures** en vistas (`action: submit`, `.onSubmit(send)`) → rompe el compilador de vistas previas. Usa `{ submit() }`.
2. `Text(cond ? "a" : "b")` **no se localiza** (lo toma como `String`). Usa `if/else` con dos `Text`.
3. Evita `@ViewBuilder func` con declaraciones `let` + `if/else` grandes que cambian de tipo: crasheó la vista previa. Divide en propiedades computadas separadas.
4. `IrisSectionHeader` tiene dos inits: `IrisSectionHeader("TÍTULO")` y `IrisSectionHeader("TÍTULO") { accesorio }`.
5. Fechas y duraciones: formatea con `Locale(identifier: "es")` en el ViewModel o usa `IrisDurationFormat` (`clock`, `overtime`, `summary`). `RootView` ya inyecta `.environment(\.locale, es)`.
6. Hojas: `.presentationSizing(.form)` o `.page` + `.presentationBackground(IrisColor.canvasElevated)`.
7. Deslizar fuera de `List`: `.swipeActions { … }` en la fila + `.swipeActionsContainer()` en el `ScrollView`. Reordenar: `ForEach(...).reorderable()` + `.reorderContainer(for: T.self) { difference in … }` (ver `ServiceOrderView`).
8. `IrisTextField` es genérico sobre el enum de foco: necesita `@FocusState private var focus: Field?` y `focus: $focus, field: .x`.
9. No uses `.transition` en el contenido cargado si la vista previa debe capturarlo (se captura a mitad del fundido).

### 1.4 Diseño — componentes a reutilizar
| Necesidad | Usa |
|---|---|
| Panel | `IrisSurface(padding:cornerRadius:)` |
| Tarjeta del Inicio | `IrisTile(title, subtitle:, systemImage:, tint:, action:) { contenido }` |
| Campo de texto | `IrisTextField` |
| Botones | `.irisPrimary(isLoading:)`, `.irisGlass`, `.irisIcon(isActive:)`, `.irisPill`, `.irisLink`, `.irisPressable` |
| Segmentado | `IrisSegmentedControl(options:selection:title:)` (opciones `Hashable & Identifiable`, título `LocalizedStringResource`) |
| Chip | `IrisChip("Texto", systemImage:, tint:)` |
| Encabezado de sección | `IrisSectionHeader` |
| Selección múltiple | `IrisCheckmark(isOn:)` |
| Banner | `IrisBanner(style:message:)` |
| "En vivo" | `IrisLiveDot`, `IrisLiveIndicator(title:)` |
| Fondo | `IrisBackground(isAnimated: false)` |
| Barra superior | `ConsoleTopBar(title:date:display:churchName:initials:onExit:onSignOut:)` |
| Barra de tiempo real vs. previsto | `TimeBar(planned:actual:scale:)` (en `Features/Home/Views/HomeTiles.swift`; muévela a `DesignSystem/Components/IrisTimeBar.swift` como `IrisTimeBar` en la Fase 7 y actualiza el uso) |
| Plan de bloques | `BlockPlanView(blocks:personName:)` (en `HomeHeroCard.swift`) |
| Duraciones | `IrisDurationFormat` |
| Colores por tipo | `ServiceItem.Kind.displayName/systemImage/tint` |

Colores semánticos para tiempos: **a tiempo** `IrisColor.success`, **por pasarse** `IrisColor.warning`, **pasado** `IrisColor.danger`.

---

## 2. Reglas de producto acordadas con el usuario (no negociables)

1. Flujo: **Login → Inicio → Iniciar servicio → Consola**. Desde la consola se vuelve con "‹ Inicio".
2. **Módulos** por iglesia: Letras (siempre activo), Biblia, Multimedia, Control de tiempo. Lo apagado **desaparece** de la UI.
3. **Tipos de servicio** (Culto general, Jóvenes, ABC…) se configuran **antes**. Los **bloques de tiempo son opcionales** por tipo; si un tipo no tiene bloques, el cronómetro **no aparece**.
4. Bloque = **nombre + minutos previstos + un solo responsable** (opcional sugerido en la plantilla).
5. **Exceso = real − previsto si > 0. Sin margen de tolerancia** (1 segundo ya cuenta).
6. Durante el servicio se puede **agregar**, **omitir** y **editar bloques pendientes**; **la plantilla no se toca**. Al terminar: "¿Guardar estos cambios en la plantilla?" → **Solo hoy / Guardar en la plantilla** (solo si hubo cambios).
7. El tiempo medido **no se edita en vivo**. En un registro guardado se puede **ajustar** la duración de un bloque y queda marcado **"ajustado"**.
8. El reloj **solo en la consola**, nunca en el TV.
9. **Solo se guardan tiempos**, nunca canciones/recursos usados.
10. Al iniciar un servicio, la **lista de contenido empieza vacía**.
11. **Tiempos**: lista por fecha + **resúmenes** con filtros por mes/rango, tipo de servicio, bloque y persona (quién se pasa más). Solo se ve en la app (sin exportar/compartir).

---

## 3. Fases

| Fase | Entregable |
|---|---|
| 1 | Capa de datos mutable (store en memoria) + target de pruebas |
| 2 | Inicio: tarjeta Tiempos compacta, navegación de tarjetas, recarga al volver |
| 3 | Pantalla **Módulos** |
| 4 | Pantalla **Personas** |
| 5 | Pantalla **Servicios** + editor de tipo de servicio y bloques |
| 6 | Iniciar servicio: consola vacía + respeto de módulos |
| 7 | **Cronómetro de bloques** en la consola + guardado del registro |
| 8 | Pantalla **Tiempos** (registros, detalle, ajuste, resúmenes) |
| 9 | Actualizar `IRIS_SPEC.md` |

---

## Fase 1 — Datos mutables y pruebas

> ✅ **Completada y revisada.** Implementada como cuatro mocks (`MockModuleSettingsRepository`, `MockServiceTypeRepository`, `MockPeopleRepository`, `MockTimeRecordRepository`) sobre un `InMemoryChurchStore` compartido; datos de ejemplo en `MockChurchData`; `BlockRecord.resolvedPersonName(in:)`; target `irisTests` con 8 pruebas. En las fases siguientes usa estos nombres (ya no existe `MockChurchRepository`).

### 1.1 Store en memoria compartido
Hoy `MockChurchRepository` es un `struct` con `static let`; los cambios no persisten entre pantallas. Crea:

`Core/Services/Mocks/InMemoryChurchStore.swift`
```swift
/// Single in-memory source of truth for the mock church data during an app run.
@Observable final class InMemoryChurchStore {
    var modules: ChurchModules
    var serviceTypes: [ServiceType]
    var people: [Person]
    var records: [ServiceRecord]   // newest first
    init(seed: …)  // usa los datos de ejemplo actuales de MockChurchRepository
}
```
Convierte `MockChurchRepository` en un `struct` que **recibe el store** (`init(store:latency:)`) y lee/escribe en él. Mantén los `static` de ejemplo para las vistas previas.

### 1.2 Amplía los protocolos (`Core/Services/ChurchRepositories.swift`)
```swift
protocol ModuleSettingsRepository {
    func modules() async throws -> ChurchModules
    func save(_ modules: ChurchModules) async throws
}
protocol ServiceTypeRepository {
    func serviceTypes() async throws -> [ServiceType]
    func save(_ type: ServiceType) async throws        // inserta o reemplaza por id
    func delete(_ id: ServiceType.ID) async throws
}
protocol PeopleRepository {
    func people() async throws -> [Person]
    func add(name: String) async throws -> Person
    func rename(_ id: Person.ID, to name: String) async throws
    func delete(_ id: Person.ID) async throws
}
protocol TimeRecordRepository {
    func records() async throws -> [ServiceRecord]     // más reciente primero
    func save(_ record: ServiceRecord) async throws     // inserta o reemplaza por id
    func delete(_ id: ServiceRecord.ID) async throws
}
```
- `AppDependencies.mock` debe crear **un solo** `InMemoryChurchStore` y pasarlo a los cuatro repositorios.
- Borrar una persona **no** borra registros: los bloques guardados mantienen su `personID`; en la UI se muestra "Persona eliminada" si no se encuentra. Borrar una persona que es responsable sugerido de una plantilla pone ese `defaultPersonID` en `nil`.

### 1.3 Modelo: registro y nombre de persona
En `BlockRecord` agrega `var personName: String?` (copia del nombre al momento de guardar) para que los registros sigan legibles si la persona se borra o renombra. La UI usa el nombre actual si existe; si no, `personName`; si no, "Sin responsable".

### 1.4 Target de pruebas
No existe. Crea un target **Unit Test** `irisTests` (herramienta `XcodeNewTarget`) usando **Swift Testing** (`import Testing`, `@Test`, `#expect`). Las pruebas de las fases 7 y 8 van ahí.

**Aceptación Fase 1**: compila; las vistas previas existentes (Inicio, Consola) siguen funcionando; el app corre igual que antes.

---

## Fase 2 — Inicio: ajustes

> ✅ **Completada y revisada.** Rutas `.modules/.services/.people/.times` con pantallas "Disponible pronto" para las fases pendientes (reemplázalas al implementar cada una en `SignedInRoot`).

### 2.1 Tarjeta Tiempos compacta (pedido del usuario)
> "En los tiempos del home no necesito que me muestre todo de golpe; solo que diga *Tiempos* y al darle clic ahí recién me dé datos."

- `TimesTile` queda **solo con el encabezado de `IrisTile`**: icono `timer` coral, título **"Tiempos"**, subtítulo **"{N} servicios registrados"** (o "Aún no hay registros"), chevron. **Sin gráfico ni métricas.**
- Elimina del `HomeViewModel` lo que solo usaba el gráfico (`lastRecordBlocks`, `BlockSummary`, `topOvertimePerson`, `lastRecordTitle`); esos cálculos se mudan a Tiempos (Fase 8). Agrega `recordCount`.
- Nuevo orden de tarjetas:
  - **Ancho (≥ 1000)**: fila 1 **Servicios · Biblioteca** (iguales); fila 2 **Tiempos · Personas · Módulos** (iguales, compactas).
  - **Angosto**: Servicios · Biblioteca / Tiempos · Personas / Módulos (a todo el ancho o junto a otra; mantén dos por fila).
  - Tiempos y Personas solo si `modules.timeControl`.
- Mantén `.fixedSize(horizontal: false, vertical: true)` por fila para igualar alturas.

### 2.2 Navegación desde las tarjetas
Amplía `SignedInNavigator.Route`:
```swift
enum Route: Equatable {
    case home, console(ServiceType), modules, services, people, times
}
```
- `IrisTile(action:)` de cada tarjeta navega: Servicios → `.services`, Tiempos → `.times`, Personas → `.people`, Módulos → `.modules`. **Biblioteca** no navega todavía (deja `action` vacío; fuera de alcance).
- `HomeViewModel` recibe closures o un `onNavigate: (Route) -> Void` (sin importar SwiftUI en el ViewModel).
- Cada pantalla nueva usa `ConsoleTopBar(title: "Módulos", …, onExit: { navigator.returnHome() })` → muestra "‹ Inicio" y el título.

### 2.3 Recargar al volver
`HomeViewModel` vive toda la sesión. Agrega `func refresh() async` (recarga módulos, tipos, personas, conteo de registros sin mostrar el spinner) y llámalo cada vez que la ruta vuelve a `.home` (`.task(id: navigator.route)` en `SignedInRoot` o `onAppear` del `HomeView`).

### 2.4 Estado vacío del hero
Si no hay tipos de servicio: el hero muestra "Crea tu primer servicio" / "Configura tus tipos de servicio y, si quieres, sus bloques de tiempo." y el botón primario **"Configurar servicios"** → `.services`.

**Aceptación Fase 2**: tarjeta Tiempos sin datos; las 4 tarjetas navegan a una pantalla placeholder o real; al volver, el Inicio refleja cambios.

---

## Fase 3 — Módulos

> ✅ **Completada y revisada.** Corrección del revisor: los guardados de `ModulesViewModel.setModule` ahora se encadenan en orden (evitaba que un guardado viejo sobrescribiera uno nuevo).

`Features/Modules/ModulesViewModel.swift`, `Features/Modules/Views/ModulesView.swift`

**Layout** (columna centrada máx. 720, `IrisSurface`):
- Título serif `IrisFont.headline` "Módulos" + "Elige qué partes de Iris usa tu iglesia. Lo que apagues desaparece de la consola."
- Una fila por módulo (`IrisSurface` interno o filas con divisores), cada una con icono tintado (40×40), título, descripción y `Toggle` (tinte `IrisColor.coral`):

| Módulo | Icono | Descripción | Toggle |
|---|---|---|---|
| Letras | `text.quote` (ember) | "Proyecta letras de canciones y anuncios. Siempre activo." | deshabilitado y encendido |
| Biblia | `book.closed.fill` (violet) | "Busca y proyecta versículos por libro, capítulo y versículo." | sí |
| Multimedia | `play.rectangle.fill` (rose) | "Música, imágenes y videos en la biblioteca y el reproductor." | sí |
| Control de tiempo | `timer` (coral) | "Mide los bloques de cada servicio y guarda sus tiempos." | sí |

- Guardado **inmediato** al cambiar (`save(modules)`), sin botón Guardar.
- Al apagar **Control de tiempo**, debajo de esa fila aparece un `IrisBanner(.info)`: "Los tiempos guardados se conservan. Puedes volver a activarlo cuando quieras."

**Efectos en el resto de la app** (implementar en esta fase):
- Inicio: ya lo respeta.
- Consola (`LiveConsoleViewModel` recibe `ChurchModules`): si `!bible` → oculta el botón Biblia; si `!multimedia` → oculta tabs Música/Imágenes/Videos en Agregar (pasa los tabs permitidos a `AddToServiceViewModel`) y el mini reproductor nunca aparece.

**Aceptación**: los toggles persisten al volver al Inicio y a la consola; vistas previas OK.

---

## Fase 4 — Personas

> ✅ **Completada y revisada** (build sin warnings, 76/76 pruebas).

`Features/People/PeopleViewModel.swift`, `Features/People/Views/PeopleView.swift`

- Solo accesible si `timeControl` está activo.
- Columna centrada máx. 720.
- Encabezado: "Personas" (serif) + "Quienes dirigen los bloques de tus servicios."
- **Agregar**: `IrisTextField("Nueva persona", icon: "person.badge.plus", prompt: "Nombre y apellido")` + botón `.irisPill` "Agregar" (Enter también agrega). Nombre vacío o duplicado (sin acentos/mayúsculas) → error en el campo: "Escribe un nombre." / "Ya existe una persona con ese nombre."
- **Lista** (orden alfabético, `es`): avatar con iniciales (colores `IrisGradient.spectrum` rotando), nombre, y a la derecha "{N} bloques" (cuántas veces aparece en registros; `IrisColor.textTertiary`).
  - Deslizar → **Eliminar** (confirmación: "¿Eliminar a {nombre}?" / "Sus tiempos guardados se conservan.").
  - Menú contextual → **Renombrar** (alerta con campo de texto) y **Eliminar**.
- Vacío: "Aún no hay personas" / "Agrega a quienes dirigen la bienvenida, las alabanzas o la prédica."

**Aceptación**: agregar/renombrar/eliminar persisten y se reflejan en el Inicio (contador) y en el editor de servicios.

---

## Fase 5 — Servicios (tipos de servicio y bloques)

> ✅ **Completada y revisada** (build sin warnings, 76/76 pruebas).

`Features/Services/ServiceTypesViewModel.swift`, `ServiceTypeEditorViewModel.swift`, `Views/ServiceTypesView.swift`, `Views/ServiceTypeEditorView.swift`

### 5.1 Lista de tipos
- Encabezado: "Servicios" + "Crea los servicios de tu iglesia y, si quieres, sus bloques de tiempo." + botón primario compacto **"+ Nuevo servicio"** (a la derecha).
- Cuadrícula adaptativa (mín. 320) de tarjetas `IrisSurface`: barra/franja del color del servicio, nombre (serif `IrisFont.title`), horario ("Domingo · 10:00" o "Sin horario"), y:
  - Con bloques (y módulo de tiempo activo): `BlockPlanView` compacto (línea de tiempo + total) y chip "⏱ {N} bloques · {total}".
  - Sin bloques: chip "Solo proyección".
- Clic en la tarjeta → abre el editor (hoja `.page`).
- Vacío: "Aún no hay servicios" + botón "Crear el primero".

### 5.2 Editor (hoja)
Encabezado: "Nuevo servicio" / "Editar servicio", botones **Cancelar** (`.irisPill`) y **Guardar** (`.irisPrimary`, ancho 180; deshabilitado si el nombre está vacío).

Secciones:
1. **Nombre** — `IrisTextField("Nombre", icon: "calendar", prompt: "Ej. Culto general")`. Duplicado → "Ya existe un servicio con ese nombre."
2. **Color** — 6 muestras circulares (36) con `IrisGradient.spectrum` + `IrisColor.success`; seleccionada con anillo blanco 2 px.
3. **Horario** (opcional) — `Toggle "Tiene horario fijo"`; si activo: selector de día (7 pastillas "Dom Lun Mar Mié Jue Vie Sáb", una seleccionada) y `DatePicker(.hourAndMinute)` estilizado oscuro.
4. **Control de tiempo** (solo si el módulo está activo) — `Toggle "Controlar el tiempo de este servicio"` + texto "Divide el servicio en bloques con un tiempo previsto y un responsable."
   - Si está activo, **editor de bloques**:
     - Fila por bloque: asa de arrastre, `TextField` nombre, **Stepper/controles − / +** de minutos (1…240, muestra "15 min"), **Menú de responsable** ("Sin responsable" + lista de personas + "Agregar persona…" que abre una alerta con campo), botón eliminar (`trash`, `.irisIcon`).
     - Reordenar arrastrando (`reorderable`).
     - Botón `.irisPill` **"+ Agregar bloque"** (nombre por defecto "Nuevo bloque", 10 min).
     - Pie: línea de tiempo `BlockPlanView` + "Total previsto: 1 h y 10 min".
     - Validación: nombre de bloque vacío → borde de error; al menos 1 bloque si el toggle está activo ("Agrega al menos un bloque o desactiva el control de tiempo.").
   - Al desactivar el toggle con bloques existentes: confirmación "¿Quitar los bloques?" / "El servicio quedará solo para proyectar."
5. **Eliminar servicio** (solo al editar) — botón destructivo de texto al final; confirmación "¿Eliminar {nombre}?" / "Sus tiempos guardados se conservan."

El editor trabaja sobre una **copia** (`draft`); solo `Guardar` persiste.

**Aceptación**: crear/editar/eliminar tipos y bloques persiste; el Inicio (hero y tarjeta Servicios) refleja los cambios; vistas previas: lista, editor nuevo, editor con bloques.

---

## Fase 6 — Iniciar servicio

> ✅ **Completada y revisada** (build sin warnings, 76/76 pruebas).

- El selector de servicio **es el hero del Inicio** (pastillas de tipo). No hagas otro modal.
- `LiveConsoleViewModel` (ya recibe `serviceType`):
  - Si `serviceType != nil`: **no** cargues `MockServicePlanRepository`; crea `ServicePlan(id:, title: serviceType.name, date: .now, items: [])` → **lista vacía**, nada en vivo, fondo = primer fondo. Sigue cargando fondos y pantalla.
  - Si `serviceType == nil` (solo vistas previas): comportamiento actual con datos de ejemplo.
- Recibe `ChurchModules` (para Fase 3) y `people` (para Fase 7).
- Mantén `LiveConsoleViewModel.preview` con datos de ejemplo.

**Aceptación**: al iniciar un servicio desde el Inicio la consola abre con "Servicio vacío"; "+ Agregar" funciona; el título de la barra es el nombre del tipo.

---

## Fase 7 — Cronómetro de bloques (consola)

> ✅ **Completada y revisada** (build sin warnings, 76/76 pruebas).

Solo si `modules.timeControl && serviceType.tracksTime`.

### 7.1 Lógica pura: `Features/LiveConsole/BlockTimer.swift`
```swift
/// Pure state machine for timing a service's blocks. Time is injected for testability.
struct BlockTimer: Equatable {
    struct Block: Identifiable, Equatable {
        let id: UUID
        var name: String
        var plannedSeconds: TimeInterval
        var personID: Person.ID?
        var startedAt: Date?
        var endedAt: Date?
        var isSkipped: Bool
        var isAddedToday: Bool         // agregado en vivo
    }
    enum Phase: Equatable { case notStarted, running, finished }

    private(set) var blocks: [Block]
    private(set) var phase: Phase
    private(set) var currentIndex: Int?

    init(template: [BlockTemplate])
    mutating func start(personID: Person.ID?, at date: Date)       // inicia el primer bloque no omitido
    mutating func advance(nextPersonID: Person.ID?, at date: Date) // cierra el actual y abre el siguiente; si no hay, termina
    mutating func finish(at date: Date)                            // cierra el actual y termina
    mutating func addBlock(name: String, plannedMinutes: Int, personID: Person.ID?) // después del actual (o al final si no empezó)
    mutating func skip(_ id: Block.ID)                             // solo bloques pendientes
    mutating func updatePending(_ id: Block.ID, name: String?, plannedMinutes: Int?, personID: Person.ID??)
    mutating func movePending(from: IndexSet, to: Int)
    mutating func setPerson(_ id: Block.ID, personID: Person.ID?)  // también para bloques ya terminados (corrección)
    func elapsed(of id: Block.ID, now: Date) -> TimeInterval
    var hasTemplateChanges: Bool                                   // hubo agregados, omitidos, editados o reordenados
    func record(serviceTypeID:, date:, peopleNames:) -> ServiceRecord // omitidos con status .skipped
    func updatedTemplate(_ original: [BlockTemplate]) -> [BlockTemplate] // para "Guardar en la plantilla" (sin los omitidos)
}
```
- Estado del reloj del bloque actual: `ratio = elapsed / planned`; **normal** < 0.9, **por pasarse** ≥ 0.9 y ≤ 1, **pasado** > 1 (sin margen).
- `LiveConsoleViewModel` guarda `blockTimer: BlockTimer?` y un tic de 1 s (`runBlockClock()` con `.task` en la vista) que solo actualiza `now` cuando `phase == .running`.

### 7.2 UI: `Features/LiveConsole/Views/BlockTimerBar.swift`
Franja **encima del espacio de trabajo** (columna 2), `IrisSurface(padding: md, cornerRadius: xl)`, alto ~72:

- **Sin empezar**: "BLOQUES" + línea de tiempo + "4 bloques · 1 h y 10 min" + botón primario compacto **"▶ Comenzar"**.
- **En curso**:
  ```
  ● PRÉDICA · Daniel Ruiz ▾      18:42 / 40:00   [−21:18]      [ Siguiente bloque → ]  [•••]  [ Terminar ]
    Bienvenida ✓ 9:40 · Alabanzas ✓ 19:05 · Prédica ● · Anuncios
  ```
  - Punto `IrisLiveDot`; nombre del bloque en mayúsculas `overline`; responsable como menú (permite corregirlo).
  - Reloj grande tabular (`title2` rounded semibold) con color según estado (texto `textPrimary` / `warning` / `danger`); a la derecha restante "−21:18" o exceso "+3:10".
  - Barra de progreso fina bajo la franja (color según estado; al pasarse, se llena y se pone `danger`).
  - Fila secundaria de "migas": bloques terminados con ✓ y su tiempo (en `danger` si se pasaron), el actual con ●, pendientes en `textTertiary`, omitidos tachados.
  - **Siguiente bloque**: abre el selector de responsable del siguiente (con el sugerido preseleccionado) y al confirmar avanza. En el último bloque el botón dice **"Terminar"**.
  - **•••** (`Menu`): "Agregar bloque…", "Editar bloques pendientes…", "Omitir siguiente bloque".
  - **Terminar** (siempre visible): confirmación "¿Terminar el servicio?" / "Se guardarán los tiempos de los bloques." → Terminar.
- **Terminado**: resumen "Servicio terminado · 1:26:10 (previsto 1:10:00 · +16:10)" + "Ver en Tiempos" (`.irisLink`, navega a `.times`).

### 7.3 Hojas/diálogos
- **Selector de responsable** (`.form`): título "¿Quién dirige {bloque}?", lista de personas con `IrisCheckmark`, la sugerida arriba con chip "Sugerido", campo "Agregar persona" al final; botones "Sin responsable" (`.irisLink`) y **"Comenzar {bloque}"** (`.irisPrimary`).
- **Agregar bloque** (`.form`): nombre, minutos, responsable → "Agregar".
- **Editar pendientes** (`.form`): lista reordenable de bloques pendientes con nombre, minutos, responsable, botón omitir/restaurar.
- **Al terminar**, si `hasTemplateChanges`: diálogo "Hoy hiciste cambios en los bloques" + descripción (p. ej. "Agregaste Santa Cena y omitiste Anuncios.") → **"Solo hoy"** / **"Guardar en la plantilla"**.
- Guarda el `ServiceRecord` con `TimeRecordRepository.save`.

### 7.4 Salir con el cronómetro en curso
"‹ Inicio" con `phase == .running` → diálogo "El servicio sigue en curso" → **"Terminar y guardar"** / **"Salir sin guardar"** (destructivo) / **"Cancelar"**.

### 7.5 Pruebas (`irisTests/BlockTimerTests.swift`)
Mínimo: iniciar/avanzar/terminar con fechas inyectadas; exceso sin margen (planned 600 s, real 601 s → pasado); omitir excluye del total; agregar en vivo marca `hasTemplateChanges`; `record` genera estados correctos; `updatedTemplate` aplica agregados/orden y quita omitidos; corregir responsable de un bloque terminado.

**Aceptación**: flujo completo Comenzar → Siguiente → … → Terminar guarda un registro visible en Tiempos; vistas previas de la franja en sus 3 estados (inyecta un `BlockTimer` ya avanzado vía `apply`).

---

## Fase 8 — Tiempos

> ✅ **Completada y revisada** (build sin warnings, 76/76 pruebas).

`Features/Times/TimesViewModel.swift`, `TimeStatistics.swift`, `Views/TimesView.swift`, `Views/TimeRecordDetailView.swift`, `Views/TimeSummaryView.swift`

Solo accesible si `timeControl` está activo. Encabezado "Tiempos" + `IrisSegmentedControl`: **Registros | Resúmenes**.

### 8.1 Registros (lista + detalle, dos columnas)
- **Izquierda (380)**: lista agrupada por mes ("OCTUBRE 2026" con `IrisSectionHeader`). Fila: punto de color del tipo, nombre del tipo, fecha ("dom 27 sept"), duración total tabular y chip de exceso ("+16:10" `danger`) o "A tiempo" (`success`). Filtro rápido arriba: menú por tipo de servicio ("Todos los servicios").
- **Derecha**: detalle del seleccionado:
  - Título "Culto general" + fecha larga; métricas: **Duración**, **Previsto**, **Exceso** (como hoy en el Inicio, tipografía `title3` rounded).
  - Por bloque: nombre + responsable, `IrisTimeBar` (real vs. previsto), real y "+4:05"/"a tiempo"; chip "Ajustado" si `status == .adjusted`; bloques omitidos en `textTertiary` con "Omitido".
  - Menú por bloque: **"Ajustar duración…"** (hoja con minutos y segundos → guarda con `status = .adjusted`) y **"Cambiar responsable"**.
  - Botón destructivo "Eliminar registro" (confirmación).
- Vacío: "Aún no hay tiempos" / "Se guardan al terminar un servicio con bloques."

### 8.2 Resúmenes
**Filtros** (fila de menús `.irisPill`):
- Periodo: "Este mes", "Mes anterior", "Últimos 3 meses", "Este año", "Todo", "Elegir mes…" (selector de mes/año).
- Servicio: "Todos" + tipos.
- Bloque: "Todos" + nombres de bloque distintos encontrados.
- Persona: "Todas" + personas.

**KPIs** (4 tarjetas pequeñas `IrisSurface`): **Servicios** (conteo), **Duración promedio**, **Exceso promedio por servicio**, **Bloques pasados** ("12 de 20 · 60 %").

**Por persona** (tabla ordenada por exceso total desc.): avatar + nombre · participaciones · veces que se pasó · exceso promedio (solo de las veces que se pasó) · exceso máximo · exceso total. Clic → **detalle de la persona** (hoja `.page`): sus bloques en el periodo (fecha, servicio, bloque, real/previsto, exceso) y sus KPIs. Pensado para "indicarle" a la persona: lenguaje neutro, sin rankings llamativos ("Se pasó en 5 de 8 bloques · promedio +6:20").

**Por bloque**: bloque · veces que se pasó / total · exceso promedio · duración real promedio vs. previsto (con `IrisTimeBar`).

### 8.3 `TimeStatistics` (puro, testeable)
```swift
struct TimeStatistics {
    struct Filter: Equatable { var period: Period; var serviceTypeID: ServiceType.ID?; var blockName: String?; var personID: Person.ID? }
    enum Period: Hashable { case thisMonth, lastMonth, last3Months, thisYear, all, month(year: Int, month: Int) }
    init(records: [ServiceRecord], filter: Filter, now: Date, calendar: Calendar)
    var serviceCount: Int
    var averageDuration: TimeInterval
    var averageOvertimePerService: TimeInterval
    var overBlocks: (over: Int, total: Int)
    var byPerson: [PersonStat]   // personID, participations, timesOver, avgOvertimeWhenOver, maxOvertime, totalOvertime
    var byBlock: [BlockStat]     // name, timesOver, total, avgOvertimeWhenOver, avgActual, avgPlanned
}
```
- Excluye bloques `.skipped` de todo cálculo. Incluye `.adjusted`.
- Filtro de bloque compara nombres sin acentos/mayúsculas.
- Pruebas (`irisTests/TimeStatisticsTests.swift`): periodos (bordes de mes), exceso sin margen, omitidos excluidos, orden por persona, promedios.

### 8.4 Mock
Amplía los registros de ejemplo a ~10 domingos (últimos 2–3 meses) con variedad de personas para que los resúmenes tengan sentido.

**Aceptación**: lista, detalle, ajuste y eliminación funcionan; filtros cambian KPIs y tablas; pruebas pasan (`RunAllTests` o `RunSomeTests`).

---

## Fase 9 — Documentación

> ✅ **Completada y revisada** (build sin warnings, 76/76 pruebas).
Actualiza `IRIS_SPEC.md` (raíz del repo): nuevas pantallas (Módulos, Personas, Servicios, Cronómetro, Tiempos), modelos y métodos de repositorio nuevos, textos nuevos en §13 y checklist §14. Mantén el mismo formato.

---

## 4. Definición de terminado (cada fase)
- [ ] `BuildProject` sin errores ni warnings nuevos.
- [ ] `RenderPreview` de cada vista nueva en horizontal y vertical (iPad Pro 13") y, si aplica, estados vacío/cargado.
- [ ] Sin colores, tamaños ni fuentes literales fuera de los tokens (salvo tamaños proporcionales ya usados en el proyecto).
- [ ] Textos en español, sin `Text(cond ? "…" : "…")`.
- [ ] Lógica en ViewModels/structs puros; vistas sin lógica.
- [ ] Datos solo vía protocolos; mocks actualizados.
- [ ] Accesibilidad: `accessibilityLabel` en botones de icono; `.isSelected` en selecciones.
- [ ] Pruebas nuevas pasan (fases 7 y 8).
- [ ] Resumen al revisor: archivos creados/modificados, decisiones tomadas y cualquier desviación de este plan.

## 5. Fuera de alcance (no implementar)
Editar/crear letras, pantalla de Biblioteca, estilos del texto en el TV, exportar/compartir tiempos, cuentas con roles, sincronización con API, salida real a TV externo, reproducción real de audio/video.
