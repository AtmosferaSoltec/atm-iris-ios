# 01 · Login: acceso real y sesión permanente

## Objetivo

Contrato §4.1 y §5: crear cuenta, iniciar sesión **una sola vez** por iPad, renovar los tokens solo y
recuperar la contraseña en 3 pasos con código. Si el iPad abre sin conexión con una sesión guardada,
entra igual y trabaja con la copia local.

## Dependencias

Fase 00.

## Pasos

### 1. `AuthSessionManager` (`Core/Auth/`)
`actor` dueño de los tokens:
- `currentAccessToken()`: si quedan < 60 s, refresca antes de devolver.
- `refresh()` con **single flight**: si ya hay un refresh en vuelo, las demás llamadas esperan ese mismo `Task`.
- `handleUnauthorized()` (lo llama el `APIClient` ante un 401 de cualquier petición que no sea de auth): refresca una vez; si el
  refresh responde 401 → `signedOut` (borra Keychain y avisa a `SessionStore`); si es red/5xx → mantiene la sesión (modo sin conexión).
- Publica cambios de sesión (`AsyncStream<SessionEvent>`): `signedIn(UserSession)`, `updated(UserSession)`, `signedOut(reason)`.
- Guarda en Keychain el refresh token y, en `Application Support/session.json`, la última `SessionView` (sin tokens) para poder
  entrar sin conexión.

### 2. `LiveAuthService`
Amplía el protocolo `AuthService` y su `MockAuthService`:
`signIn`, `signUp`, `signOut`, `signOutAll`, `requestPasswordReset(email)`, `verifyResetCode(email, code)`,
`resetPassword(email, code, password, confirmation)`, `switchChurch(churchID)` (fase 03), `currentSession()`.
- `client = { platform: "ios", deviceName: UIDevice.current.name }` (si devuelve el genérico "iPad", úsalo igual).
- Errores: `AuthError` pasa a llevar el `code` y el `message` del API (`.api(code:message:fieldErrors:)`) además de `.network`.
  Los formularios muestran `fieldErrors` en su campo y el resto en el banner.
- Restaura la validación de "Entrar" (correo y contraseña obligatorios), quitando la "fase de maqueta" de `AuthViewModel`.

### 3. Arranque
- `RootView`/`SessionStore`: al abrir, mientras corre el splash, `AuthSessionManager.restore()`:
  - sin refresh token → acceso;
  - con refresh token → entra **de inmediato** con la `SessionView` guardada y, en segundo plano, refresca; si el refresh dice
    401 → vuelve al acceso con el banner "Tu sesión expiró. Vuelve a iniciar sesión."; si no hay red → sigue dentro.
- Cerrar sesión (menú de la cuenta): `signOut` en el API (si falla por red, igual limpia lo local), borra Keychain y la sesión
  guardada. La limpieza de la copia local la agrega la fase 02.

### 4. Recuperación en 3 pasos
Reemplaza el flujo de enlace de `PasswordRecoveryView` por tres pasos dentro del mismo modal (mismo estilo):
1. **"Recupera tu acceso"**: correo (precargado) → "Enviar código". Siempre avanza (el API no revela si existe).
2. **"Revisa tu correo"**: "Si {correo} tiene una cuenta de Iris, te llegó un código. Vence en 15 minutos." + campo de 6 dígitos
   (`.textContentType(.oneTimeCode)`, teclado numérico, dígitos grandes con tracking) → "Continuar"; link "Reenviar código" con
   espera de 60 s; errores del API en el campo.
3. **"Crea tu nueva contraseña"**: nueva + confirmar (mínimo 8, deben coincidir) → "Guardar". Éxito: cierra el modal y muestra en el
   acceso el banner de éxito "Tu contraseña quedó actualizada. Inicia sesión con la nueva."
Emblema e indicador "Paso N de 3" como la web (`../atm-iris-web/src/features/auth/components/recovery/`, solo de referencia visual).
`PasswordRecoveryViewModel`: `Phase` = `email | code | newPassword | done`, con `apply(...)` y `preview` por fase.

## Criterios de aceptación

- Con la API corriendo: crear cuenta, cerrar sesión, entrar, cerrar la app y volver a abrirla sin pedir contraseña
  (verificación manual rápida en el simulador; las pruebas formales van en la fase 10).
- Vistas previas de los 3 pasos de recuperación.
- `BuildProject` limpio.

## Desviaciones

_(Completar al cerrar la fase.)_
