param(
    [string]$OutputPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "extractor-vegeta-image.tar")
)

$ErrorActionPreference = "Stop"

& docker image inspect extractor-vegeta:local *> $null
if ($LASTEXITCODE -ne 0) {
    throw "No esta instalada la imagen extractor-vegeta:local. Ejecuta primero .\build-image.ps1"
}

& docker save --output $OutputPath extractor-vegeta:local
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Imagen exportada en: $OutputPath"
Write-Host "En otra computadora se carga con: docker load -i `"$OutputPath`""
