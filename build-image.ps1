$ErrorActionPreference = "Stop"

$kitDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
& docker build -t extractor-vegeta:local $kitDirectory
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Imagen lista: extractor-vegeta:local"
