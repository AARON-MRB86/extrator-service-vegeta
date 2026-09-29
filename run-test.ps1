param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$DocumentId,

    [ValidateRange(1, 1000)]
    [int]$Rate = 2,

    [ValidatePattern('^\d+(ms|s|m|h)$')]
    [string]$Duration = "5s",

    [string]$ExtractorUrl = "http://host.docker.internal/api/v1/extract",

    [string]$HostHeader = "extraccion.localhost"
)

$ErrorActionPreference = "Stop"
$kitDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$volume = "type=bind,source=$kitDirectory,target=/work"

& docker image inspect extractor-vegeta:local *> $null
if ($LASTEXITCODE -ne 0) {
    throw "No esta instalada la imagen extractor-vegeta:local. Ejecuta primero .\build-image.ps1"
}

$bodyPath = Join-Path $kitDirectory "request-body.json"
$targetsPath = Join-Path $kitDirectory "targets-generated.txt"
$bodyJson = @{ document_id = $DocumentId } | ConvertTo-Json -Compress
[IO.File]::WriteAllText($bodyPath, $bodyJson, [Text.Encoding]::ASCII)

$targetLines = @("POST $ExtractorUrl")
if (-not [string]::IsNullOrWhiteSpace($HostHeader)) {
    $targetLines += "Host: $HostHeader"
}
$targetLines += "Content-Type: application/json"
$targetLines += "@request-body.json"
[IO.File]::WriteAllLines($targetsPath, $targetLines, [Text.Encoding]::ASCII)

$resultsFile = "extractor-$((Get-Date).ToString('yyyyMMdd-HHmmss')).bin"
Write-Host "Prueba: $Rate solicitudes/segundo durante $Duration; document_id=$DocumentId"
Write-Host "Target: $ExtractorUrl"

& docker run --rm `
    --mount $volume `
    --workdir /work `
    extractor-vegeta:local `
    attack "-targets=targets-generated.txt" "-rate=$Rate" "-duration=$Duration" "-output=/work/$resultsFile"
if ($LASTEXITCODE -ne 0) {
    throw "Vegeta termino con error durante el ataque."
}

Write-Host "`nReporte de Vegeta:"
& docker run --rm `
    --mount $volume `
    --workdir /work `
    extractor-vegeta:local `
    report "-type=text" "/work/$resultsFile"
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo generar el reporte de Vegeta."
}

Write-Host "`nResultados guardados en: $(Join-Path $kitDirectory $resultsFile)"
