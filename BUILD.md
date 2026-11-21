# Compilación, pruebas e instalación

## M3 · Verificar el proyecto original

Requisitos del verificador local: macOS, Xcode con iOS SDK 26 o posterior, simulador iPhone con iOS 26 o posterior, Python 3 y Git. En GitHub Actions el job selecciona Xcode 26.6 en un runner `macos-26`. Selecciona iPhone 15 Pro si está disponible. Un UUID de simulador explícito se puede proporcionar mediante `STRSK_SIMULATOR_ID`. [Software del runner](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md).

Desde el repositorio de auditoría:

```bash
git clone https://github.com/knp-org/luma-ios.git ../luma-ios
git -C ../luma-ios checkout --detach 7006a4b51aa3bc5a1175036ea7ec83034fdccbfe
scripts/verify-luma-baseline.sh ../luma-ios "$(mktemp -d)"
```

El script verifica el SHA y el estado limpio, compila Release para iOS arm64 sin firma y ejecuta los tests unitarios y de interfaz del esquema original en simulador. Guarda el inventario de SDK, logs y paquetes `.xcresult`. Usa un directorio de resultados nuevo por ejecución. El workflow fija el checkout upstream y las revisiones de sus acciones. [Workflow](.github/workflows/ios-baseline.yml).

## Pruebas portables

Con Swift 6.3, Python 3 y los clones fijados de Luma y Erhu en un directorio común:

```bash
scripts/test-portable-upstream.sh /ruta/a/los/checkouts
```

## IPA · M10

El proyecto STRSK derivado tendrá un identificador propio y `UIBackgroundModes = audio`. Para el build de AltStore se usará Release, SDK de dispositivo y arm64. El empaquetado toma el directorio `.app` de ese build, lo copia manteniendo su estructura bajo `Payload/` y comprime `Payload` en una IPA. Se verifican el contenido, plataforma, arquitectura, identificador y código fuente correspondiente antes de distribuir. La IPA preparada para que AltStore la firme y la validación del binario ya firmado en hardware son dos verificaciones distintas. M3 reúne evidencia de compilación y pruebas del original.

Para instalar la IPA de STRSK cuando esté disponible, configurar AltServer y AltStore Classic, activar el Modo de desarrollador si iOS lo solicita, abrir la IPA desde el botón **+** de **My Apps** o desde Archivos e instalar. Mantener la firma vigente mediante la actualización de AltStore. En el primer arranque se comprueban audio local, bloqueo, Control Center, AirPlay y reanudación. La arquitectura de la app usa frameworks nativos sin JIT ni jailbreak. La instalación aún requiere validación en iPhone 15 Pro. [Guía de AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore).
