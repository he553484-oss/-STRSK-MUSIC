# Compilación, pruebas e instalación

## M3 · Verificar el proyecto original

El verificador local requiere macOS, Xcode con iOS SDK 26 o posterior, simulador iPhone con iOS 26 o posterior, Python 3 y Git. GitHub documenta el runner `macos-26` con Xcode 26.6 e iOS Simulator 26.5. El job prefiere un iPhone 15 Pro configurado e intenta crearlo si la imagen ofrece el tipo de dispositivo para ese runtime. Si CoreSimulator no puede crearlo, el job usa un iPhone compatible y registra el modelo efectivo. En macOS se puede seleccionar un UUID con `STRSK_SIMULATOR_ID`. [Runners disponibles](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) · [Inventario de Xcode y simuladores](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md).

Desde el repositorio de auditoría:

```bash
git clone https://github.com/knp-org/luma-ios.git ../luma-ios
git -C ../luma-ios checkout --detach 7006a4b51aa3bc5a1175036ea7ec83034fdccbfe
scripts/verify-luma-baseline.sh ../luma-ios "$(mktemp -d)"
```

El script verifica el SHA y el estado limpio del checkout original. Ejecuta Release para iOS arm64, `build-for-testing` en simulador y, si compila, `test-without-building` con los tests unitarios y de interfaz del esquema Luma. Los tres comandos usan `CODE_SIGNING_ALLOWED=NO`. Guarda el inventario de SDK, el destino efectivo, los logs y los paquetes `.xcresult`. Usa un directorio de salida nuevo por ejecución. [Workflow](.github/workflows/ios-baseline.yml).

### Ejecutar en GitHub Actions

Usar un repositorio GitHub de destino con Actions habilitado, acceso de escritura para publicar workflows y cuota para un runner macOS. Si la variable de token de esta sesión sigue siendo inválida, limpia esas variables en la terminal antes de iniciar sesión. Sustituye `OWNER/REPO` por el destino autorizado.

```bash
cd /workspace/STRSK-MUSIC
unset GH_TOKEN GITHUB_TOKEN
gh auth login --hostname github.com --git-protocol https --web
gh auth refresh --hostname github.com --scopes workflow
gh auth setup-git --hostname github.com

repo=OWNER/REPO
branch=m3/luma-baseline
commit="$(git rev-parse HEAD)"
git push "https://github.com/$repo.git" "HEAD:refs/heads/$branch"
gh run list -R "$repo" --workflow ios-baseline.yml --branch "$branch" \
  --commit "$commit" --event push --limit 5
```

GitHub activa el job con ese push. Si la lista todavía está vacía, vuelve a consultarla tras unos segundos. Usa el ID que corresponda al SHA publicado.

```bash
read -r -p 'ID del run mostrado por GitHub: ' run_id
gh run watch "$run_id" -R "$repo" --exit-status
gh run view "$run_id" -R "$repo" --log > "luma-baseline-$run_id.log"
artifacts="$(mktemp -d)"
gh run download "$run_id" -R "$repo" -n luma-baseline-validation -D "$artifacts"
cat "$artifacts/upstream-commit.txt" "$artifacts/selected-simulator.txt" "$artifacts/status.log"
if [ -f "$artifacts/xcode-results.tar.gz" ]; then
  tar -xzf "$artifacts/xcode-results.tar.gz" -C "$artifacts"
fi
```

Descarga los artefactos también cuando el job falle. Una ejecución cancelada o detenida antes de compilar puede dejar solo el log del job. M3 queda validado cuando el SHA coincide con Luma fijado y el Release, la compilación de simulador y su suite devuelven cero. Conserva el enlace del run y sus resultados antes de iniciar M4.

## Pruebas portables

Con Swift 6.3, Python 3 y los clones fijados de Luma y Erhu en un directorio común:

```bash
scripts/test-portable-upstream.sh /ruta/a/los/checkouts
```

## M4 · Build y firma para AltStore Classic

El proyecto se abre con Xcode 26.6 y conserva el esquema interno `Luma` para ejecutar las pruebas existentes. El nombre que muestra iOS es **STRSK MUSIC**. En `Build Settings`, ajusta `STRSK_BUNDLE_IDENTIFIER` para establecer un identificador válido y consistente. El valor inicial es `com.strskmusic.player`. Los objetivos de pruebas derivan sus identificadores del mismo ajuste. Se conserva el modo de audio en segundo plano.

El [workflow de M4](.github/workflows/ios-strsk.yml) construye el fork y genera una IPA de dispositivo sin firma, con su SHA-256. El paquete corresponde al commit `b2ee079`. [IPA arm64 y SHA-256](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44948114019/artifacts/14725376094).

Localmente se obtiene el mismo tipo de paquete en macOS:

```bash
results="$(mktemp -d)"
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$results/build" \
  STRSK_BUNDLE_IDENTIFIER=com.strskmusic.player ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build

scripts/package-strsk-ipa.sh "$results/build/Build/Products/Release-iphoneos/Luma.app" \
  "$results/STRSK-MUSIC-unsigned.ipa"
(cd "$results" && shasum -a 256 -c STRSK-MUSIC-unsigned.ipa.sha256)
```

El script comprueba el nombre, la plataforma de dispositivo y la arquitectura arm64, y empaqueta bajo `Payload/STRSK MUSIC.app`. La IPA de CI carece de firma y perfil de aprovisionamiento. La cuenta Apple y el dispositivo de destino son necesarios para obtener una firma válida mediante AltStore. [AltServer](https://faq.altstore.io/altstore-classic/altserver).

1. Instala AltServer en tu Mac o PC y, desde AltServer, instala AltStore Classic en el iPhone. Usa tu propia cuenta Apple y sigue los pasos de confianza del [instalador oficial de AltStore Classic](https://faq.altstore.io/altstore-classic/how-to-install-altstore-classic).
2. Activa **Modo de desarrollador** en **Ajustes → Privacidad y seguridad** si iOS lo solicita. Reinicia y confirma. [Documentación de Apple](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device/).
3. Descarga y descomprime el artefacto `strsk-unsigned-ipa`. Guarda `STRSK-MUSIC-unsigned.ipa` en Archivos. Abre AltStore Classic, entra en **My Apps**, toca **+** y selecciona la IPA. Mantén el iPhone conectado por USB o en la misma red que AltServer mientras firma e instala. [AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore) · [AltServer](https://faq.altstore.io/altstore-classic/altserver).
4. En el iPhone, abre la app e importa una pista desde Archivos. Comprueba reproducción con pantalla bloqueada, Control Center, reanudación y, si tienes una ruta disponible, AirPlay. La app usa AVFoundation y SwiftUI sin JIT ni jailbreak.

Para ejecutar directamente desde Xcode en un iPhone emparejado, elige tu Apple Development Team y un identificador disponible en **Signing & Capabilities**, con firma automática. Mantén la identidad y los certificados en el llavero local. CI usa `CODE_SIGNING_ALLOWED=NO`. El repositorio público carece de credenciales Apple, certificados privados y perfiles. Una prueba de instalación con AltStore en hardware sigue pendiente.

## M5 · Letras de archivos locales

1. Importa la canción desde Archivos con **Import music**. Abre **Now Playing → Lyrics** o el menú **Lyrics** de la pista.
2. Selecciona **Import lyrics file** y el archivo de esa pista. STRSK conserva la asociación en SQLite. Si la pista ya está seleccionada, pulsar una línea busca su marca sin cambiar el estado de pausa.
3. En **Timing & scroll** ajusta el retraso de las letras y el tiempo para volver al seguimiento tras un desplazamiento manual. El ajuste de retraso se aplica además del offset del archivo.

Enhanced LRC acepta etiquetas de inicio por palabra y un marcador final opcional. Por ejemplo, `[00:02]<00:02>Lo <00:03>cal<00:04>` contiene dos intervalos completos. Las palabras cuyo fin se desconoce reciben un resaltado fijo al llegar su inicio. YRC y KRC se leen como texto decodificado. El perfil TTML incluye contenedores paralelos, párrafos y spans, tiempos de reloj y relativos, agentes explícitos y spans con rol de traducción.

El workflow ejecuta el esquema original sobre el fork y graba otra ejecución del recorrido de karaoke. Las pruebas crean archivos originales de audio y Enhanced LRC e invocan los mismos importadores que usa Archivos. XCTest exporta las capturas. `simctl` graba la pantalla real del simulador. El audio y las letras de prueba solo se generan en builds Debug mediante los argumentos de prueba. [Auditoría de componentes](M5_COMPONENT_AUDIT.md).

## M6 · Compilar BitChord sin modificaciones

El verificador requiere un Mac Apple Silicon y Xcode 27, que compila contra el SDK declarado por BitChord. La prueba de arranque prefiere un runtime iOS 26 para iPhone 15 Pro y registra la versión que ejecuta. Si iOS 26 no está instalado en CI, el workflow intenta descargar iOS 26.5 y admite un runtime posterior como alternativa. Usa JDK 21, Rust y sus tres targets Apple, CMake, XcodeGen y Python 3. Gradle usa el wrapper que trae el checkout fijado. [Workflow del original](.github/workflows/ios-bitchord-baseline.yml) · [Auditoría M6](M6_BITCHORD_AUDIT.md).

```bash
export DEVELOPER_DIR=/Applications/Xcode_27.app/Contents/Developer
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
brew install cmake xcodegen
rustup target add aarch64-apple-darwin aarch64-apple-ios aarch64-apple-ios-sim

export BITCHORD_REVISION=9c20ef321f311a3dd3f051ebd820abbc8f952413
git clone https://github.com/bagumamartin/BitChord.git ../bit-chord-original
git -C ../bit-chord-original checkout --detach "$BITCHORD_REVISION"
export RUNNER_TEMP="$(mktemp -d)"
export EVIDENCE_DIR="$RUNNER_TEMP/bitchord-evidence"
scripts/verify-bitchord-baseline.sh ../bit-chord-original
cat "$EVIDENCE_DIR/stages.txt"
```

El script construye NativeCoreFFI y BitChordShared, genera el proyecto Xcode y ejecuta Release arm64 y Release para simulador con firma deshabilitada. Conserva los paquetes de resultados que produce Xcode, el inventario de destinos y la captura si la app original abre en el runtime seleccionado. Los tests automatizados de Rust, Kotlin/Native y los verificadores Swift se ejecutan por separado. El proyecto fijado genera una app y un widget sin target XCTest para iOS.

Para instalar una IPA de STRSK MUSIC usa el procedimiento de AltStore Classic de M4 y el artefacto del commit que quieras validar. Una captura del simulador de BitChord y una IPA de STRSK de M5 tienen alcances distintos. En BitChord original, los App Groups, iCloud y el widget requieren comprobar los entitlements resultantes en el perfil del dispositivo. Ninguna comprobación del simulador acredita firma, instalación en un iPhone ni audio con pantalla bloqueada.

El artefacto M6 contiene la IPA arm64 sin firma de `73c63ef`, su SHA-256, las licencias y la referencia al código fuente. [IPA M6 para firmar mediante AltStore Classic](https://github.com/he553484-oss/-STRSK-MUSIC/actions/runs/44965710415/artifacts/14731494964).

### Biblioteca remota de STRSK

Abre **Listen → Remote Library** e introduce la dirección HTTPS de una carpeta WebDAV a la que tengas acceso. La conexión acepta un servidor público o autenticación HTTP Basic sobre TLS. La app recuerda la dirección de la última conexión exitosa en el dispositivo. El usuario y la contraseña se mantienen durante la sesión de catálogo. Si la carpeta usa una jerarquía como `Artista/Álbum/Pista.wav`, las agrupaciones de artistas y álbumes se basan en ella.

Seleccionar una pista descarga el archivo completo a la biblioteca y empieza a reproducirlo con el motor local. Un archivo de letras del mismo nombre base, como `Pista.lrc` o `Pista.ttml`, puede incorporarse al mismo tiempo si la pista aún no tiene letras. El audio queda disponible para cola, playlists y reproducción sin conexión. Las playlists de STRSK se guardan en SQLite. WebDAV es de solo lectura y representa la colección de ese servidor.

Para repetir la prueba de transporte y la prueba de interfaz, inicia la fixture local del commit fijado. El ejecutable de transporte requiere Swift 6. La prueba XCTest requiere el simulador y el servidor activo durante la ejecución.

```bash
fixture="$(mktemp -d)"
scripts/start-webdav-test-server.sh ../bit-chord-original "$fixture"
trap 'kill "$(cat "$fixture/server.pid")"' EXIT
swiftc -swift-version 6 -o "$fixture/check" Luma/WebDAVLibrary.swift scripts/WebDAVTransportCheck.swift
"$fixture/check"

# En macOS, con un simulador arrancado.
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Debug \
  -destination "platform=iOS Simulator,id=$STRSK_SIMULATOR_ID" \
  -only-testing:LumaUITests/LumaUITests/testAuthorizedWebDAVMusicPlaysWithImportedKaraoke \
  CODE_SIGNING_ALLOWED=NO test
```
