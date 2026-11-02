# Iris · iPad

Control remoto de Iris para iPad. Hoy es una **maqueta**: pantallas con datos de ejemplo, sin conexión real.

- `iris/DesignSystem`: colores, tipografía y componentes de Iris.
- `iris/Mockup`: emparejamiento (`PairingScreen`), control en vivo (`RemoteScreen`) y Biblia (`BibleSheet`).

```sh
open iris.xcodeproj        # esquema "iris", destino: un iPad con iPadOS 27
# Para abrir directo el control en vivo: argumento de lanzamiento  -connected
```

Requisitos: Xcode 27 y el simulador de iPadOS 27 (`IPHONEOS_DEPLOYMENT_TARGET = 27.0`, solo iPad).
