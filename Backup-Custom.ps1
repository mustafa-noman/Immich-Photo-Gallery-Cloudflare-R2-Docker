param(
    [string]$BackupRoot = ""
)

$ErrorActionPreference = "Stop"

# Resolve script root (which is the project root directory)
$projectRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($projectRoot)) {
    $projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Default backup root to ./backup
if ([string]::IsNullOrEmpty($BackupRoot)) {
    $BackupRoot = Join-Path $projectRoot "backup"
}

# Format folder name as custom_{yymmdd_hhmmss}
$stamp = "custom_" + (Get-Date -Format "yyMMdd_HHmmss")
$destination = Join-Path $BackupRoot $stamp
$containerDump = "/tmp/immich-$stamp.dump"

Write-Host "[*] Creating backup directory: $destination" -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $destination | Out-Null

# Run pg_dump inside Postgres container
Write-Host "[*] Exporting PostgreSQL database dump..." -ForegroundColor Yellow
docker exec my-photo-gallery-immich-postgres pg_dump -U postgres -d immich --format=custom --file=$containerDump
if ($LASTEXITCODE -ne 0) {
    Write-Error "PostgreSQL dump failed."
    exit 1
}

# Copy the dump file from container to host
try {
    Write-Host "[*] Copying dump file to host..." -ForegroundColor Yellow
    docker cp "my-photo-gallery-immich-postgres:$containerDump" (Join-Path $destination "immich-postgres.dump")
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Copying PostgreSQL dump failed."
        exit 1
    }
}
finally {
    # Clean up the temporary dump file inside the container
    docker exec my-photo-gallery-immich-postgres rm -f $containerDump | Out-Null
}

# Copy environment configuration files
Write-Host "[*] Copying compose files and configurations..." -ForegroundColor Yellow
Copy-Item -LiteralPath (Join-Path $projectRoot "docker-compose.yml") -Destination $destination
Copy-Item -LiteralPath (Join-Path $projectRoot ".env") -Destination $destination

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "   Backup Completed Successfully!" -ForegroundColor Green
Write-Host "   Location: $destination" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
