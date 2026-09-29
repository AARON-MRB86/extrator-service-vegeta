# Pruebas de carga para extraccion-service

Kit para ejecutar Vegeta en Docker desde Windows PowerShell. No instala Vegeta
en Windows y no llama a resumen-service ni a Gemini: las solicitudes van
directamente a `POST /api/v1/extract`.

## Requisitos

- Windows 10/11 con Docker Desktop iniciado y usando contenedores Linux.
- PowerShell y `curl.exe` (incluido en Windows moderno).
- `documentos-service` y `extraccion-service` disponibles desde la computadora.
- Un PDF real y valido. El PDF se sube una vez a documentos-service; Vegeta
  repite solicitudes usando su `document_id`, no vuelve a enviar el archivo.

## Instalar y construir

Descarga o copia la carpeta completa `extrator-service-vegeta` a la PC del
profesor. Abre PowerShell en esa carpeta. Por ejemplo:

```powershell
Set-Location "D:\ruta\imagen-vegeta\extrator-service-vegeta"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\build-image.ps1
```

La primera construccion necesita Internet para descargar la imagen publica
`peterevans/vegeta:latest`. Despues crea la imagen local
`extractor-vegeta:local`, que incluye el ejecutable Vegeta.

Para preparar una PC sin Internet, en una maquina con Docker construye y exporta:

```powershell
.\build-image.ps1
.\export-image.ps1
```

Copia `extractor-vegeta-image.tar` junto con esta carpeta al equipo del
profesor y carga la imagen alli:

```powershell
docker load -i .\extractor-vegeta-image.tar
```

Docker Desktop debe estar instalado y en ejecucion en ambos equipos. El archivo
`.tar` puede ser grande; el `.gitignore` evita que se agregue al repositorio.

## Levantar servicios de prueba

Si se usara el stack de este proyecto, desde la carpeta
`orquestador-service\infra` se pueden levantar solo Traefik, Mongo, documentos y
extraccion:

```powershell
docker compose up -d traefik mongo documentos extraccion
```

No es necesario configurar Gemini: la prueba no llama al servicio de resumen.
Con el compose normal, Traefik publica el puerto `80`. Si se usa un override
que publica `8081`, se debe indicar ese puerto tanto al subir el PDF como al
dirigirse a extraccion.

Tambien se puede usar un contenedor local del extractor publicado en el puerto
`8002`. Comprueba su salud desde PowerShell:

```powershell
Invoke-RestMethod http://localhost:8002/health
```

Debe indicar `status=ok` y `service=extraccion-service`.

## Subir un PDF y obtener su ID

El comando usa el gateway de documentos en `http://localhost` y le envia el
host `documentos.localhost`, como espera la configuracion de Traefik del
proyecto. Cambia la ruta del ejemplo por la ubicacion real del PDF:

```powershell
$documentId = .\upload-document.ps1 `
  -PdfPath "C:\Users\Profesor\Downloads\prueba.pdf" `
  -Name "PDF de prueba"
Write-Host "document_id=$documentId"
```

El script imprime y devuelve el `id` asignado por documentos-service. Para un
gateway en otro puerto, por ejemplo `8081`, agrega:

```powershell
-DocumentsBaseUrl "http://localhost:8081"
```

El archivo debe ser un PDF valido, no un `.txt` renombrado. Si el servidor
responde `409` porque ese PDF ya existe, no lo subas de nuevo: usa el ID que
recibiste al subirlo originalmente. Si no tienes ese ID, usa un PDF diferente
o consulta al responsable de los documentos disponibles.

## Ejecutar Vegeta

### Extractor del stack detras de Traefik (predeterminado)

```powershell
.\run-test.ps1 -DocumentId $documentId -Rate 2 -Duration 5s
```

Esta prueba intenta unas 10 solicitudes. `-Rate` es solicitudes por segundo y
`-Duration` es el tiempo total. Por ejemplo, 5 solicitudes/s durante 20s son
aproximadamente 100 solicitudes:

```powershell
.\run-test.ps1 -DocumentId $documentId -Rate 5 -Duration 20s
```

El script usa por defecto `http://host.docker.internal/api/v1/extract` y el host
`extraccion.localhost`, para que Traefik enrute la solicitud.

Si Traefik esta publicado en `8081`, agrega el puerto:

```powershell
.\run-test.ps1 `
  -DocumentId $documentId `
  -Rate 2 `
  -Duration 5s `
  -ExtractorUrl "http://host.docker.internal:8081/api/v1/extract" `
  -HostHeader "extraccion.localhost"
```

### Extractor local publicado en el puerto 8002

Si ya se tiene un contenedor local de extraccion publicado en `8002`, usa:

```powershell
.\run-test.ps1 `
  -DocumentId $documentId `
  -Rate 2 `
  -Duration 5s `
  -ExtractorUrl "http://host.docker.internal:8002/api/v1/extract" `
  -HostHeader ""
```

La prueba muestra el reporte con cantidad, tasa, throughput, latencias,
porcentaje de exito, codigos HTTP y errores. El binario con los resultados se
guarda en esta carpeta como `extractor-AAAAMMDD-HHMMSS.bin`; es un artefacto
local y no debe subirse a Git.

## Cambiar de PDF

1. Ejecuta `upload-document.ps1` con la ruta del nuevo PDF y un nombre.
2. Guarda el `document_id` que devuelve el script.
3. Ejecuta `run-test.ps1` usando ese ID. No es necesario editar archivos JSON:
   el script genera el body de Vegeta en cada ejecucion.

## Precauciones

- Empieza con una carga corta y moderada; sube la tasa gradualmente y confirma
  que tienes permiso antes de hacer pruebas intensas.
- Cada solicitud procesa el documento indicado. Una tasa alta puede consumir
  CPU y memoria del extractor.
- Si sale un error de conexion, comprueba primero `/health`, el puerto publicado
  y que Docker Desktop este activo.
- Los resultados `.bin` son archivos binarios y se pueden analizar con el
  reporte del script; no los abras como texto.

## Redmi

Si "Redmi" significa una laptop Redmi con Windows, instala Docker Desktop para
Windows y sigue los pasos anteriores.

Si se trata de un telefono Redmi con Android, no puede ejecutar Docker Desktop
ni esta imagen Docker de forma soportada. Ejecuta Docker/Vegeta en una PC con
Docker Desktop; el telefono puede servir para consultar la documentacion o
controlar esa PC de forma remota, pero no reemplaza al equipo que ejecuta los
contenedores.
