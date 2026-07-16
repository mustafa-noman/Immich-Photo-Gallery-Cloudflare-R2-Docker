param(
    [string]$BackupRoot = ""
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptRoot)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if ([string]::IsNullOrEmpty($BackupRoot)) {
    $BackupRoot = Join-Path (Split-Path -Parent $scriptRoot) "backup"
}
$projectRoot = Split-Path -Parent $scriptRoot
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$destination = Join-Path $BackupRoot $stamp
$containerDump = "/tmp/immich-$stamp.dump"

New-Item -ItemType Directory -Force -Path $destination | Out-Null

docker exec my-photo-gallery-immich-postgres pg_dump -U postgres -d immich --format=custom --file=$containerDump
if ($LASTEXITCODE -ne 0) { throw "PostgreSQL dump failed." }

try {
    docker cp "my-photo-gallery-immich-postgres:$containerDump" (Join-Path $destination "immich-postgres.dump")
    if ($LASTEXITCODE -ne 0) { throw "Copying PostgreSQL dump failed." }
}
finally {
    docker exec my-photo-gallery-immich-postgres rm -f $containerDump | Out-Null
}

Copy-Item -LiteralPath (Join-Path $projectRoot "docker-compose.yml") -Destination $destination
Copy-Item -LiteralPath (Join-Path $projectRoot ".env") -Destination $destination
Write-Host "Backup created: $destination" -ForegroundColor Green
