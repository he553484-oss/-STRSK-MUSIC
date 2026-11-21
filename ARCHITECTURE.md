# Arquitectura · M2

**Decisión.** La base será Luma en `7006a4b51aa3bc5a1175036ea7ec83034fdccbfe`. Su biblioteca local importa archivos, persiste selecciones y prueba migración y recuperación. El único motor local inicial será su implementación AVAudioPlayer, con la programación anticipada de `GaplessScheduler` usando el reloj del dispositivo. El primer refactor extraerá interfaces al ritmo de los cambios que las necesiten. [Auditoría](REPOSITORY_AUDIT.md).

## Contratos previstos

| Interfaz | Contrato |
|---|---|
| `MusicSourceProvider` | Recibe consulta y cursor. Devuelve página de referencias y capacidades de cada resultado. Errores tipados de configuración, autorización, cuota, red y respuesta inválida. Cancelación de tareas obsoletas. |
| `PlaybackEngine` | Carga una URL local accesible, expone identidad y generación de pista, posición absoluta en el medio, duración opcional, velocidad y estados vacío, cargando, reproduciendo, pausado, interrumpido, finalizado y error. Play, pause y seek. |
| `LibraryRepository` | Abre, guarda y restaura snapshots con error explícito y orden de escritura. El acceso a SQLite, codificación y lectura pesada quedan fuera del hilo principal. Mantiene compatibilidad con registros anteriores. Se extraerá el contrato sobre la clase homónima de Luma al aparecer un primer consumidor. |
| `LyricsProvider` | Carga un documento local, de texto pegado o de una fuente autorizada. Entrega ausencia, texto plano o líneas temporizadas con palabras opcionales y traducción si viene identificada por la fuente. |
| `LyricsSynchronizer` | Dados una generación de pista, un índice temporal inmutable, un instante del motor y el desfase del usuario, devuelve línea y palabra activas junto al avance de los intervalos que tienen duración conocida. |
| `ArtworkProvider` | Resuelve portada en tamaño objetivo, por identidad y variante. Cancela trabajo obsoleto y devuelve ausencia cuando faltan imágenes válidas. Reutiliza ImageIO y caché de Luma. |
| `ThemeManager` | Resuelve paleta y contraste a partir de preferencias y carátula. Respeta Reduce Motion y apariencia del sistema. |
| `QueueManager` | Produce el siguiente elemento reproducible a partir de contexto, cambios manuales, historial, shuffle y repeat. Opera con IDs locales. El motor recibe esa instrucción y no gestiona una segunda cola. |

El adaptador de presentación de Luma conserva aislamiento `@MainActor` para estado de interfaz, transporte y AVAudioSession. Un cambio de pista incrementa la generación y cancela cargas anteriores. Un resultado tardío con otra generación se descarta. El catálogo online presenta referencias con acciones explícitas y abre las URLs oficiales mediante el sistema. Cada frontera se prueba antes de cambiar el siguiente consumidor.

## Letras

Indexar una vez al cambiar el documento. Establecer milisegundos enteros acotados, orden estable, búsqueda binaria directa sobre las líneas y palabras, y una regla reproducible para empates. Cuando dos entradas empiezan en el mismo instante se selecciona la última del orden del documento para el cursor, conservando ambas para la vista. Validar offsets sin desbordamiento. Migrar el signo del offset según los archivos y expectativas previas de Luma, que difieren de Erhu. Preservar silencios intencionales, texto plano y variantes de idioma identificadas.

Adaptar el parser Enhanced LRC de Erhu y evaluar AudioMarker para TTML dentro del mismo modelo. Las palabras se destacan con sus tiempos explícitos. Si una palabra tiene inicio y carece de final, se puede medir avance hasta el siguiente marcador explícito o hasta el final de línea explícito. Si tampoco hay final verificable se resalta sin barrido progresivo. Un documento con tiempos de línea activa exclusivamente la línea. Las letras conservan la opción de importarse y consultarse offline.

El avance visual parte de la posición del motor. Las actualizaciones de pantalla consultan ese reloj y sirven solo para renderizar. Pause, seek, cambio de velocidad, interrupción y retorno de segundo plano se reconcilian con el estado actual del motor. El scroll sigue cambios de línea y permite inspección manual. VoiceOver lee la línea completa y describe la acción de seek.

## YouTube

Usar YouTube Data API v3 para `search.list` de videos musicales, canales como referencias de artistas, y miniaturas y metadatos entregados por la API. Las playlists públicas o autorizadas usan `playlists.list` y `playlistItems.list`. Las playlists del usuario requieren OAuth y alcance de lectura. El login nativo usará OAuth de Google con su SDK oficial o AppAuth si los parámetros de cliente y redirección están admitidos para el bundle firmado. Los tokens quedan en Keychain y se eliminan localmente al desconectar. El catálogo admitirá guardados e historial de acciones internos con controles de borrado y renovación o eliminación de los datos de API según la política aplicable. El reloj y la cola local reciben exclusivamente audio importado. [Búsqueda oficial](https://developers.google.com/youtube/data/reference/rest/v3/search/list) · [Playlists](https://developers.google.com/youtube/data/reference/rest/v3/playlists/list) · [Elementos de playlist](https://developers.google.com/youtube/data/reference/rest/v3/playlistItems/list) · [OAuth nativo](https://developers.google.com/identity/protocols/oauth2/native-app) · [Políticas de datos y reproducción](https://developers.google.com/youtube/terms/developer-policies).

En M8 se validarán marca y atribución de YouTube, enlaces a YouTube Music para referencias que correspondan, cuotas, URLs HTTPS permitidas, revocación y errores HTTP. YouTube Data API permite consultar recursos de YouTube. La disponibilidad exacta de una referencia en YouTube Music depende del contenido, la región y la cuenta. La app entregará la reproducción a la aplicación o página oficial. Para el catálogo público se evaluará una clave configurada fuera del repositorio y restringida al uso previsto, o un intermediario propio si la clave no puede protegerse adecuadamente en el cliente.
