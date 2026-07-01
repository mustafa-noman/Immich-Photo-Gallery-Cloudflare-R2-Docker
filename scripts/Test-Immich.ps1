[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

try {
    if ((docker context show) -ne "desktop-linux") {
        throw "Docker context must be local desktop-linux."
    }

    docker compose config --quiet
    if ($LASTEXITCODE -ne 0) { throw "Compose validation failed." }

    docker compose ps
    if ($LASTEXITCODE -ne 0) { throw "Unable to read Compose service status." }

    docker exec my-photo-gallery-immich-postgres pg_isready -U postgres -d immich
    if ($LASTEXITCODE -ne 0) { throw "Immich PostgreSQL is not ready." }

    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:2283/api/server/ping" -TimeoutSec 15
    if ($response.StatusCode -ne 200) { throw "Immich HTTP health check failed." }

    Write-Host "Immich stack healthy at http://localhost:2283" -ForegroundColor Green
}
finally {
    Pop-Location
}
