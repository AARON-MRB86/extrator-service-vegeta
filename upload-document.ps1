param(
    [Parameter(Mandatory = $true)]
    [string]$PdfPath,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$DocumentsBaseUrl = "http://localhost"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $PdfPath -PathType Leaf)) {
    throw "No se encontro el archivo: $PdfPath"
}

$pdfFullPath = (Resolve-Path -LiteralPath $PdfPath).Path
if ([IO.Path]::GetExtension($pdfFullPath) -ine ".pdf") {
    throw "El archivo debe tener extension .pdf."
}

$endpoint = "$($DocumentsBaseUrl.TrimEnd('/'))/api/v1/documents"
$responseLines = & curl.exe `
    --silent `
    --show-error `
    --write-out "`n__HTTP_STATUS__:%{http_code}" `
    -H "Host: documentos.localhost" `
    -F "name=$Name" `
    -F "file=@${pdfFullPath};type=application/pdf" `
    $endpoint

if ($LASTEXITCODE -ne 0) {
    throw "curl.exe fallo al contactar documentos-service. Verifica la URL y que el stack este levantado."
}

$responseText = ($responseLines -join "`n").Trim()
$statusMatch = [regex]::Match($responseText, '(?s)\r?\n__HTTP_STATUS__:(\d{3})\s*$')
if (-not $statusMatch.Success) {
    throw "No se pudo leer el codigo HTTP de la respuesta: $responseText"
}

$statusCode = [int]$statusMatch.Groups[1].Value
$responseBody = $responseText.Substring(0, $statusMatch.Index).Trim()
if ($statusCode -eq 409) {
    throw "documentos-service indica que ese PDF ya existe. No lo vuelvas a subir; usa el document_id de la subida original. Respuesta: $responseBody"
}
if ($statusCode -lt 200 -or $statusCode -ge 300) {
    throw "La subida fallo con HTTP $statusCode. Respuesta: $responseBody"
}

try {
    $document = $responseBody | ConvertFrom-Json
}
catch {
    throw "documentos-service no devolvio JSON valido: $responseBody"
}

if ($null -eq $document.id) {
    throw "La respuesta no contiene el campo id: $responseBody"
}

$documentId = [int]$document.id
Write-Host "PDF subido. document_id=$documentId"
Write-Output $documentId
