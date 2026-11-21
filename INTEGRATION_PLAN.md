# Hitos y criterios de avance

| Hito | Estado | Evidencia o criterio de salida |
|---|---|---|
| M1 · Clonar y auditar | Completado | Cuatro clones completos, siete candidatos adicionales, matriz, código, historial, licencias y CI público. [Auditoría](REPOSITORY_AUDIT.md) |
| M2 · Elegir base y arquitectura | Completado | Selección de Luma y un motor local, contratos y alcance de reutilización. [Arquitectura](ARCHITECTURE.md) |
| M3 · Verificar Luma original | Completado | Release arm64 y build de simulador aprobados. 41 pruebas unitarias y 10 de interfaz aprobadas en iPhone 15 Pro, iOS 26.5. [GitHub Actions](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44935462635) |
| M4 · Fork STRSK | Completado en simulador | Identidad STRSK y pantallas SwiftUI validadas con los builds de dispositivo y simulador, 41 pruebas unitarias y 11 de interfaz. La IPA sin firma está disponible para AltStore. [GitHub Actions](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44948114019) |
| M5 · Letras | Pendiente | Adoptar Enhanced LRC y TTML en el mismo índice. Probar precisión, seek, cambios rápidos, repetidos, vacíos, outliers, malformed y carga larga. |
| M6 · Interfaz | Pendiente | Diseño STRSK, Now Playing, mini reproductor, cola, gestos, Liquid Glass donde convenga y controles accesibles. Pruebas de VoiceOver, Dynamic Type y Reduce Motion. |
| M7 · Biblioteca | Pendiente | Importar archivos reales, reabrir la app y verificar biblioteca, favoritos, playlists, búsqueda y recuperación. Stress de importación y reanudación. |
| M8 · YouTube autorizado | Pendiente | Probar búsqueda, paginación, canales, playlists y errores con el proveedor oficial. Verificar OAuth y borrado con una cuenta de prueba autorizada. |
| M9 · Audio y rendimiento | Pendiente | Trazas de Instruments y resultados por formato en iPhone 15 Pro. Medir arranque, memoria, CPU, fluidez y batería. Evaluar EQ y crossfade con un único motor. |
| M10 · Release e IPA | Pendiente | Tests en CI, Release arm64, paquete verificable, firma AltStore y prueba de instalación y audio en iPhone 15 Pro. |

Cada hito de aplicación requiere build, test y commit que registre la evidencia. Un fallo queda abierto en el hito donde se observó.

## Preparación de M5

La revisión dirigida confirmó dos puntos de integración. Erhu ya parsea Enhanced LRC con marcadores explícitos y aporta pruebas del cursor. MRSC `WordLine` sirve como referencia de renderizado, pero `wordTimings(for:end:)` estima tiempos cuando faltan. En M5 se adaptará el parser de Erhu con sus avisos GPLv3 y se conectará el renderizado de SwiftUI al reloj de Luma. Si solo hay tiempos de línea, se activará el resaltado por línea.

La regresión obligatoria incluye un offset de `Int64.min` con una línea y palabras válidas. Tras ignorar el offset inválido, deben conservarse sus marcas originales. Probar también que el resaltado se detiene con pausa, responde a seek en ambos sentidos y descarta el documento anterior al cambiar de canción. La prueba de interfaz debe verificar que una pulsación sobre la línea hace seek a su marca y que el scroll sigue la nueva posición. Estas pruebas se ejecutarán sobre el fork una vez validado M3. [Procedencia](COMPONENT_PROVENANCE.md).

## Pruebas de integración previstas

- Letras con intervalos originales de prueba. Verificar bordes de palabra y línea a un milisegundo de cada marcador, desfases extremos, reanudación, cambio de velocidad, seek adelante y atrás, repetidos, silencios, TTML malformado y un documento largo. Reportar por separado error del índice y latencia de presentación. Medir frames y scroll con render real.
- Audio y biblioteca con fixtures autorizados y archivos reales en Archivos. Play, pause, seek, cola manual, shuffle, repeat, restauración, borrado, sesiones interrumpidas, ruta remota y comparación de forma de onda en transiciones gapless.
- API con respuestas reproducibles y pruebas autorizadas de extremo a extremo. Offline, timeout, errores de cuota y permisos, respuesta inválida, vuelta de OAuth, paginación y enlaces externos. Mantener las credenciales de pruebas fuera del historial de Git.
