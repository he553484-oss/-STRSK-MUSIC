# STRSK MUSIC 3.0

Reproductor musical SwiftUI para iPhone 15 Pro, iOS 26 o posterior y AltStore Classic. Incluye biblioteca local, playlists y karaoke sincronizado. La rama M6 incorpora una biblioteca remota WebDAV desde la que puedes buscar y descargar audio a tu biblioteca.

M1 y M2 completados. Luma es la base elegida, en `7006a4b51aa3bc5a1175036ea7ec83034fdccbfe`. Su proyecto Xcode original se mantiene en un checkout separado. M3 pasó en el simulador de iPhone 15 Pro con iOS 26.5. M4 adapta el fork en SwiftUI con identidad STRSK. Conserva la biblioteca local, SQLite, AVAudioPlayer, cola, playlists, importación desde Archivos y las letras por línea. [GitHub Actions](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44935462635). [Proyecto original fijado](https://github.com/knp-org/luma-ios/tree/7006a4b51aa3bc5a1175036ea7ec83034fdccbfe/Luma.xcodeproj).

**M4 validado en iPhone 15 Pro simulado.** 41 pruebas unitarias y 11 de interfaz pasaron. La firma y la instalación en dispositivo se realizan con AltStore Classic. [GitHub Actions](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44948114019) · [IPA sin firma](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44948114019/artifacts/14725376094) · [Capturas y resultados de Xcode](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44948114019/artifacts/14725460886).

**M5 validado.** Karaoke nativo con Enhanced LRC, LRC, TTML y YRC/KRC textuales. La prueba de recorrido importa audio y letras reales, comprueba reproducción, pausa y seek, y guarda capturas. [CI de iOS](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44954613736) · [MP4, capturas y resultados](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44954613736/artifacts/14726799609) · [IPA sin firma](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44954613736/artifacts/14726554985).

| Documento | Contenido |
|---|---|
| [REPOSITORY_AUDIT.md](REPOSITORY_AUDIT.md) | SHA, candidatos, matriz, código y evidencia upstream |
| [M5_COMPONENT_AUDIT.md](M5_COMPONENT_AUDIT.md) | Código reutilizado para letras, commits y licencias |
| [M6_BITCHORD_AUDIT.md](M6_BITCHORD_AUDIT.md) | BitChord fijado, compilación original y decisión de integración |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Base, motor y contratos seleccionados |
| [COMPONENT_PROVENANCE.md](COMPONENT_PROVENANCE.md) | Tabla de funciones, archivos, pruebas y limitaciones |
| [LICENSES.md](LICENSES.md) | Atribución, licencias y distribución |
| [INTEGRATION_PLAN.md](INTEGRATION_PLAN.md) | Criterios de salida de M1 a M10 |
| [BUILD.md](BUILD.md) | Verificación independiente en macOS y preparación de AltStore |
| [TEST_RESULTS.md](TEST_RESULTS.md) | Evidencia local y verificación del proyecto original |
