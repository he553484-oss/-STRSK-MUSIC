# Resultados · 21 de noviembre de 2026

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
