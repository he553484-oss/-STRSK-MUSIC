# Resultados · 21 de noviembre de 2026

## M5 · Karaoke nativo en iOS

GitHub Actions probó `8a1795234743c08cf053faa0d5c0ce07316c60c1` con Xcode 26.6 (17F113), Release iPhoneOS arm64 y un simulador iPhone 15 Pro con iOS 26.5. [Run exitoso](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44954613736).

| Verificación | Resultado |
|---|---|
| Build Release de dispositivo y build para iPhone Simulator | Ambos aprobados. |
| Swift Testing | 54 pruebas en cinco suites, sin fallos. Se verifica el offset extremo de Erhu, sílabas TTML, voces simultáneas, traducciones, Unicode y RTL, corrupción, tiempos duplicados o fuera de orden y el índice de intervalos. |
| Importación y reloj | Archivos de audio y Enhanced LRC escritos en disco. Se comprobaron los importadores del producto, la asociación SQLite, pausa, cambios de posición, reanudación a 1,5× y cambio de pista con AVAudioPlayer. |
| XCTest UI | 12 pruebas sin fallos. La nueva prueba reproduce una pista de audio original importada con su archivo Enhanced LRC y comprueba el estado al pausar, buscar una línea y entrar en un intervalo instrumental. La automatización invoca el importador directamente para preparar el archivo, sin interactuar con el selector del sistema. |
| Evidencia visual | Tres PNG de XCTest y `STRSK-Karaoke.mp4` generados por una ejecución adicional del mismo recorrido. `screenshots/manifest.json` relaciona las etiquetas de captura con los PNG. [Capturas, video y xcresult](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44954613736/artifacts/14726799609). |
| Distribución | IPA arm64 sin firma, SHA-256, licencias y referencia al código fuente que generó el binario. [Artefacto IPA](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44954613736/artifacts/14726554985). |

La prueba del índice con 12.000 líneas y 1.400 búsquedas por salto tardó 0,037 s en el simulador de CI. Es la duración del test completo del índice, con aserciones, y no mide el renderizado ni el rendimiento del iPhone físico. Quedan pendientes las trazas de CPU, batería y FPS en hardware.

El flujo de prueba no sustituye el reloj ni genera posiciones de reproducción. XCTest escribe archivos originales y el reproductor los importa, persiste y reproduce con la misma ruta de producción. La descarga del ZIP de evidencia desde el entorno de trabajo devolvió HTTP 403. GitHub confirmó su publicación y el log identifica el MP4 y los PNG individuales. [Extracto del log](evidence/strsk-m5-ci.log).

## M4 · STRSK MUSIC en un iPhone 15 Pro simulado

GitHub Actions probó el fork en `b2ee07903a766a65d044e4d08b20f00c3c17b1c6` sobre macOS arm64 con Xcode 26.6 (17F113). El simulador fue iPhone 15 Pro con iOS 26.5. [Run exitoso](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44948114019).

| Verificación | Resultado |
|---|---|
| Build Release para dispositivo | Aprobado. `com.strskmusic.player`, iPhoneOS arm64. |
| Build de la app y objetivos de pruebas para simulador | Aprobado. |
| Swift Testing | 41 pruebas en cuatro suites, sin fallos. |
| XCTest UI | 11 pruebas, sin fallos. Incluye navegación a álbum, reproducción y vuelta al mini reproductor. |
| Capturas | XCTest exportó PNG reales de inicio, biblioteca, álbum y Now Playing. [Capturas y resultados de Xcode](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44948114019/artifacts/14725460886). |
| IPA | Paquete arm64 sin firma verificado por el script de CI. [IPA y checksum](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44948114019/artifacts/14725376094). |

La ejecución anterior al arreglo de arranque pasó 41 pruebas unitarias y 10 de interfaz. El caso de instalación limpia agotó el tiempo al iniciar el proceso de XCTest. El workflow comenzó a arrancar CoreSimulator antes de ejecutar la suite. El run siguiente pasó las 52 pruebas, pero un parámetro decorativo de la barra de estado falló. Se retiró ese paso y se dejó que XCTest instalara y abriera la app. [Timeout de arranque](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44946000063) · [52 pruebas aprobadas con el fallo del paso de preparación](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44947541276).

Los logs están disponibles. La descarga de los ZIP de artefactos desde este entorno devolvió HTTP 403. La firma con una cuenta Apple y la instalación en un iPhone físico siguen pendientes. [Extracto verificable](evidence/strsk-ios-ci.log).

## M3 · Validación en GitHub Actions

El runner GitHub macOS arm64 ejecutó Xcode 26.6 (17F113) con el árbol original de Luma en SHA `7006a4b51aa3bc5a1175036ea7ec83034fdccbfe`. El workflow exitoso corresponde al commit `7bf0169` de la rama `m3/luma-baseline`. [GitHub Actions](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44935462635).

| Verificación | Resultado |
|---|---|
| Build Release arm64 para iOS | Éxito. Código de salida 0. |
| Build para pruebas en iPhone Simulator | Éxito. Código de salida 0. |
| Suite del esquema Luma en iPhone 15 Pro, iOS 26.5 (arm64) | 41 pruebas unitarias en cuatro suites y 10 pruebas de interfaz, sin fallos. Código de salida 0. |

La primera ejecución falló antes de compilar porque un argumento adicional `+` se pasó a `xcode-select`. El commit `7bf0169` corrigió los dos comandos afectados del workflow. El código de Luma se mantuvo intacto. El run exitoso publicó los resultados de Xcode. Se recuperó el log del run, pero la descarga del ZIP en este entorno devolvió HTTP 403. [Primer run](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44935367637) · [Artefacto publicado](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44935462635/artifacts/14720246336) · [Extracto del log](evidence/ios-baseline-ci.log).

## Verificación inicial en Linux

Entorno Debian 13, Linux x86_64. Swift 6.3.2 se instaló para ejecutar pruebas portables. El checkout original de Luma se comprobó limpio en `7006a4b51aa3bc5a1175036ea7ec83034fdccbfe`.

| Verificación | Resultado | Alcance |
|---|---|---|
| Luma Release arm64 y tests del proyecto original | Bloqueados | Se invocó `xcodebuild` para cada uno. Ambos intentos devolvieron `xcodebuild: command not found`. El script de CI confirma el bloqueo con código 127. Linux carece del SDK de iOS y simulador de Xcode. |
| Subconjunto portable de Luma | 8 pruebas pasaron | Suite upstream `LyricsServiceTests`. Cubre codificación, ranking, errores, cancelación y cooldown con URLProtocol local. Se extrajo `LyricsDocument` de `Models.swift` y se importó FoundationNetworking solo en las copias temporales. Hubo un aviso Linux de Sendable en URLProtocol. |
| Parser portable de Erhu | 8 pruebas pasaron | Archivos del parser sin modificar. La clase `LyricsParserTests` se extrajo del archivo de pruebas que contiene otras suites. Cubre límites de línea y palabra, Enhanced LRC, repetición, offset, vacíos y texto plano. |
| Entrada fuera de rango de Erhu | Fallo upstream reproducido | El parser original terminó con código 132 al procesar `[offset:-9223372036854775808]` seguido de una línea válida. Requiere una regresión antes de reutilizarse. |
| AudioMarker original por SwiftPM | Falló en Linux | Las referencias a XMLParser y XMLParserDelegate del código original requieren FoundationXML en Linux. Se inspeccionó el CI de macOS del SHA en la auditoría. |
| AudioMarker con adaptación temporal | 30 pruebas pasaron | Filtros `TTMLParserTests\|LRCParserTests`, en copia de `git archive` con imports Linux FoundationXML en TTMLParser y PodloveXMLExporter. El working tree original se mantuvo limpio. |
| Workflow GitHub Actions | Sintaxis aprobada | `actionlint` 1.7.11. No se ejecutó el job macOS. El workspace carece de sesión GitHub válida y repositorio remoto de destino. |

## Evidencia local

- [Salida de compilación original](evidence/ios-baseline.log)
- [Salida de las dos suites portables](evidence/portable-upstream.log)
- [Resumen de AudioMarker](evidence/audio-marker.log)

Los 46 tests portables son de candidatos upstream. No se ha observado la app abierta ni la integración de STRSK. Importación nativa, reproducción, persistencia, temporización con reloj real, render, red autorizada, firma e instalación siguen pendientes. No se midieron CPU, latencia, memoria, FPS ni batería en iPhone. No se produjo una IPA.

## Preparación del workflow antes de publicarlo

Se verificó el SHA y el estado limpio del checkout original. El inventario publicado para `macos-26` confirma Xcode 26.6 y el simulador iOS 26.5. El workflow separa los resultados de Release, compilación de simulador y ejecución de la suite, y guarda los paquetes Xcode en un tar comprimido. La ejecución local volvió a detenerse con código 127 porque falta `xcodebuild`. En ese momento faltaba una credencial válida y el job macOS todavía estaba pendiente. [Comandos para publicar y recoger los resultados](BUILD.md#ejecutar-en-github-actions).

`actionlint` 1.7.11 y `bash -n` pasaron. Con ejecutables de prueba en Linux se comprobaron cinco rutas del script: creación del iPhone 15 Pro, uso de un iPhone alternativo, UUID explícito, fallo de compilación de simulador y fallo de tests. Estas pruebas verifican la lógica del script. Se repitieron las dos suites portables existentes. Pasaron 8 pruebas de Luma y 8 de Erhu.
