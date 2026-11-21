# Hitos y criterios de avance

| Hito | Estado | Evidencia o criterio de salida |
|---|---|---|
| M1 · Clonar y auditar | Completado | Cuatro clones completos, siete candidatos adicionales, matriz, código, historial, licencias y CI público. [Auditoría](REPOSITORY_AUDIT.md) |
| M2 · Elegir base y arquitectura | Completado | Selección de Luma y un motor local, contratos y alcance de reutilización. [Arquitectura](ARCHITECTURE.md) |
| M3 · Verificar Luma original | Bloqueado tras intento | Release arm64 y suite del esquema original deben pasar en Xcode. [Resultados](TEST_RESULTS.md) |
| M4 · Fork STRSK | Pendiente | Preservar ascendencia del SHA auditado y avisos. Sustituir marca y configurar firma propia. Mantener funcionalidad y suite original. |
| M5 · Letras | Pendiente | Adoptar Enhanced LRC y TTML en el mismo índice. Probar precisión, seek, cambios rápidos, repetidos, vacíos, outliers, malformed y carga larga. |
| M6 · Interfaz | Pendiente | Diseño STRSK, Now Playing, mini reproductor, cola, gestos, Liquid Glass donde convenga y controles accesibles. Pruebas de VoiceOver, Dynamic Type y Reduce Motion. |
| M7 · Biblioteca | Pendiente | Importar archivos reales, reabrir la app y verificar biblioteca, favoritos, playlists, búsqueda y recuperación. Stress de importación y reanudación. |
| M8 · YouTube autorizado | Pendiente | Probar búsqueda, paginación, canales, playlists y errores con el proveedor oficial. Verificar OAuth y borrado con una cuenta de prueba autorizada. |
| M9 · Audio y rendimiento | Pendiente | Trazas de Instruments y resultados por formato en iPhone 15 Pro. Medir arranque, memoria, CPU, fluidez y batería. Evaluar EQ y crossfade con un único motor. |
| M10 · Release e IPA | Pendiente | Tests en CI, Release arm64, paquete verificable, firma AltStore y prueba de instalación y audio en iPhone 15 Pro. |

Cada hito de aplicación requiere build, test y commit que registre la evidencia. Un fallo queda abierto en el hito donde se observó.

## Pruebas de integración previstas

- Letras con intervalos originales de prueba. Verificar bordes de palabra y línea a un milisegundo de cada marcador, desfases extremos, reanudación, cambio de velocidad, seek adelante y atrás, repetidos, silencios, TTML malformado y un documento largo. Reportar por separado error del índice y latencia de presentación. Medir frames y scroll con render real.
- Audio y biblioteca con fixtures autorizados y archivos reales en Archivos. Play, pause, seek, cola manual, shuffle, repeat, restauración, borrado, sesiones interrumpidas, ruta remota y comparación de forma de onda en transiciones gapless.
- API con respuestas reproducibles y pruebas autorizadas de extremo a extremo. Offline, timeout, errores de cuota y permisos, respuesta inválida, vuelta de OAuth, paginación y enlaces externos. Mantener las credenciales de pruebas fuera del historial de Git.
