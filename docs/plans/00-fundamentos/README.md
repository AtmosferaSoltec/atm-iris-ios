# 00 · Fundamentos

## Objetivo

Las piezas que usan todas las fases: configuración por entorno, cliente HTTP del contrato, modelos
de transporte (DTO), almacenamiento seguro y el interruptor entre datos de prueba y reales.

## Pasos

### 1. Configuración
- `Config/Debug.xcconfig` y `Config/Release.xcconfig` con `IRIS_API_BASE_URL` (Debug: `http://localhost:3020/api/v1`;
  Release: vacío por ahora). Exponla en el `Info.plist` como `IrisAPIBaseURL` y léela en `Core/Config/AppConfig.swift`.
- ATS: `NSAppTransportSecurity › NSAllowsLocalNetworking = YES` para poder usar `http` contra la Mac en la red local
  (un iPad físico usa la IP de la Mac). No abras `NSAllowsArbitraryLoads`.
- **Modo de datos**: `enum DataMode { case mock, live }`. Por defecto `live`. El argumento de arranque `-IrisDataMode mock`
  (en el esquema de Xcode, desactivado) fuerza los mocks. `AppDependencies.live` y `.mock` (este ya existe). Las vistas
  previas siguen usando `.mock`.

### 2. Modelos de transporte (`Core/Networking/DTO/`)
- Un `Codable` por tipo del contrato (`AuthResultDTO`, `SessionViewDTO`, `ChurchDTO`, `PersonDTO`, `ServiceTypeDTO`,
  `SongDTO`, `SongSummaryDTO`, `MediaAssetDTO`, `ServiceRecordDTO`, `SyncPageDTO`, `BibleDownloadDTO`, `DeviceSessionDTO`,
  `APIErrorBody`, `Paginated<T>`, `DataEnvelope<T>`) con los **nombres exactos** del contrato. Enums con `String` en
  minúsculas y un caso desconocido tolerante (`case unknown` vía `init(from:)`) para no romper si el API agrega valores.
- `Core/Networking/DTO/Mapping.swift`: DTO ⇄ modelos de `Core/Models` (los modelos de la app **no** son los DTO).
- `JSONDecoder`/`JSONEncoder` compartidos: fechas ISO-8601 **con milisegundos** (formateador propio; el `.iso8601` estándar
  no acepta fracciones), `keyEncodingStrategy` por defecto (los nombres ya son camelCase).

### 3. Cliente HTTP (`Core/Networking/APIClient.swift`)
- `actor APIClient` sobre `URLSession` con `async/await`: `send<T: Decodable>(_ request: APIRequest) async throws -> T`
  que desempaqueta `{ data }`, `sendPage<T>` para listas paginadas, `sendVoid` para 204.
- `APIRequest` describe método, ruta, query, cuerpo `Encodable`, y si requiere token.
- Errores tipados: `enum APIError: Error { case http(status: Int, body: APIErrorBody), network(URLError), decoding(Error), unauthorized }`
  con `message` en español (el del cuerpo, o los genéricos del contrato para red y 5xx). Mapea `URLError` de conectividad a `network`.
- Cabecera `X-Request-Id` (UUID) en cada petición; regístrala con `Logger` (`os.Logger`, subsistema `com.atmosfera.iris`,
  categoría `network`) junto con método, ruta, estado y duración. **Nunca** registres tokens ni contraseñas.
- La inyección del access token y el refresh los resuelve `AuthSessionManager` (fase 01): el cliente recibe un
  `tokenProvider` y un `onUnauthorized` para no depender de él directamente.

### 4. Keychain (`Core/Auth/TokenStore.swift`)
- `protocol TokenStore` con `load() -> StoredTokens?`, `save(_:)`, `clear()`. `KeychainTokenStore` guarda el refresh token,
  su vencimiento y el último access token como un único ítem `kSecClassGenericPassword` (servicio `com.atmosfera.iris.session`,
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). `InMemoryTokenStore` para vistas previas y pruebas.

### 5. Modelos de la app
- `UserSession` pasa a: `userID`, `email`, `fullName`, `church` (`id`, `name`, `timeZone: TimeZone`), `role`, `permissions: Set<Permission>`,
  `churches: [ChurchSummary]`, `sessionID`, `platform`. Elimina `churchName`/`leaderName` y ajusta todos los usos
  (Inicio, barra superior, iniciales de la cuenta, mocks, vistas previas).
- `enum Permission: String` con el catálogo del contrato §3 y `session.can(.songsManage)`.
- `Calendar.church(timeZone:)`: un `Calendar` gregoriano con la zona de la iglesia y `Locale("es")`. Úsalo en todo cálculo de
  "hoy", horarios y periodos (Inicio, Tiempos, cronómetro). Reemplaza `Calendar.current` donde corresponda.
- `nameKey` (`String+NameKey.swift`): alinéalo con el contrato §2 (colapsar espacios internos además de lo que ya hace).

## Criterios de aceptación

- `BuildProject` limpio; las vistas previas siguen funcionando con `.mock`.
- Un archivo de ejemplo del contrato (el `AuthResult` de §5) se decodifica sin errores (verifícalo con un `#Preview` o un
  `print` temporal; las pruebas formales van en la fase 10).

## Desviaciones

_(Completar al cerrar la fase.)_
