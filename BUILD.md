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

## IPA · M10

El proyecto STRSK derivado tendrá un identificador propio y `UIBackgroundModes = audio`. Para el build de AltStore se usará Release, SDK de dispositivo y arm64. El empaquetado toma el directorio `.app` de ese build, lo copia manteniendo su estructura bajo `Payload/` y comprime `Payload` en una IPA. Se verifican el contenido, plataforma, arquitectura, identificador y código fuente correspondiente antes de distribuir. La IPA preparada para que AltStore la firme y la validación del binario ya firmado en hardware son dos verificaciones distintas. M3 reúne evidencia de compilación y pruebas del original.

Para instalar la IPA de STRSK cuando esté disponible, configurar AltServer y AltStore Classic, activar el Modo de desarrollador si iOS lo solicita, abrir la IPA desde el botón **+** de **My Apps** o desde Archivos e instalar. Mantener la firma vigente mediante la actualización de AltStore. En el primer arranque se comprueban audio local, bloqueo, Control Center, AirPlay y reanudación. La arquitectura de la app usa frameworks nativos sin JIT ni jailbreak. La instalación aún requiere validación en iPhone 15 Pro. [Guía de AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore).
