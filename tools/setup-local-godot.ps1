# Makes sure the local Godot used for the web export is installed (same version as docker/Dockerfile).
# One-time downloads from the official Godot GitHub releases:
#   - Godot editor (console exe) into C:\Tools\Godot\<version>\
#   - only the two web export templates into %APPDATA%\Godot\export_templates\<version>.stable\
#     (copied from the Docker build cache when possible, the ~1 GB download is only a fallback)
# Dot-source it: . .\tools\setup-local-godot.ps1   -> sets $GodotExe
$GodotVersion = '4.6.3'
$godotDir = "C:\Tools\Godot\$GodotVersion"
$GodotExe = "$godotDir\Godot_v$GodotVersion-stable_win64_console.exe"
$templatesDir = "$env:APPDATA\Godot\export_templates\$GodotVersion.stable"
$release = "https://github.com/godotengine/godot/releases/download/$GodotVersion-stable"

if (-not (Test-Path $GodotExe)) {
    Write-Host "Downloading Godot $GodotVersion (one time)..."
    $zip = "$env:TEMP\godot-$GodotVersion-win64.zip"
    curl.exe -fL --progress-bar -o $zip "$release/Godot_v$GodotVersion-stable_win64.exe.zip"
    if ($LASTEXITCODE -ne 0) { throw "download of Godot $GodotVersion failed" }
    New-Item -ItemType Directory -Force $godotDir | Out-Null
    Expand-Archive -Force $zip $godotDir
    Remove-Item $zip
}

if (-not (Test-Path "$templatesDir\web_nothreads_release.zip")) {
    # Fast path: the Docker build cache usually already holds them (templates stage of docker/Dockerfile).
    Write-Host "Copying the web export templates from the Docker build cache..."
    $repoRoot = Split-Path $PSScriptRoot
    docker buildx build -f "$repoRoot\docker\Dockerfile" --target templates-out --build-arg GODOT_VERSION=$GodotVersion -o "type=local,dest=$env:APPDATA\Godot\export_templates" $repoRoot
}

if (-not (Test-Path "$templatesDir\web_nothreads_release.zip")) {
    Write-Host "Downloading Godot $GodotVersion export templates (one time, ~1 GB, only the web ones are kept)..."
    $tpz = "$env:TEMP\godot-$GodotVersion-templates.tpz"
    curl.exe -fL --progress-bar -o $tpz "$release/Godot_v$GodotVersion-stable_export_templates.tpz"
    if ($LASTEXITCODE -ne 0) { throw "download of the export templates failed" }
    $tmp = "$env:TEMP\godot-$GodotVersion-templates"
    New-Item -ItemType Directory -Force $tmp, $templatesDir | Out-Null
    tar.exe -xf $tpz -C $tmp templates/version.txt templates/web_release.zip templates/web_nothreads_release.zip
    if ($LASTEXITCODE -ne 0) { throw "extracting the export templates failed" }
    Move-Item -Force "$tmp\templates\*" $templatesDir
    Remove-Item -Recurse -Force $tmp, $tpz
}

Write-Host "Godot $GodotVersion ready: $GodotExe"
