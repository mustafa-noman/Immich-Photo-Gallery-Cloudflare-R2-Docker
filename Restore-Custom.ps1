$ErrorActionPreference = "Stop"

# Resolve script root (which is the project root directory)
$projectRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($projectRoot)) {
    $projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$BackupRoot = Join-Path $projectRoot "backup"

if (-not (Test-Path $BackupRoot)) {
    Write-Error "Backup directory not found at $BackupRoot"
    exit 1
}

# Get list of directories (backups)
$backups = Get-ChildItem -Path $BackupRoot -Directory | Sort-Object LastWriteTime -Descending

if ($backups.Count -eq 0) {
    Write-Host "No backup directories found in $BackupRoot" -ForegroundColor Red
    exit 1
}

Write-Host "Available Backups:" -ForegroundColor Yellow
for ($i = 0; $i -lt $backups.Count; $i++) {
    $num = $i + 1
    $name = $backups[$i].Name
    $date = $backups[$i].LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    if ($i -eq 0) {
        Write-Host "  [$num] $name ($date) [Default - Latest]" -ForegroundColor Green
    } else {
        Write-Host "  [$num] $name ($date)"
    }
}

$selection = Read-Host "Select backup to restore [1-$($backups.Count)] (Default: 1)"
if ([string]::IsNullOrEmpty($selection)) {
    $selectionIndex = 0
} else {
    if (-not [int]::TryParse($selection, [ref]$val) -or $val -lt 1 -or $val -gt $backups.Count) {
        Write-Error "Invalid selection: $selection"
        exit 1
    }
    $selectionIndex = $val - 1
}

$selectedBackup = $backups[$selectionIndex]
$backupFolder = $selectedBackup.FullName
$dumpFile = Join-Path $backupFolder "immich-postgres.dump"

if (-not (Test-Path $dumpFile)) {
    Write-Error "Dump file not found at $dumpFile"
    exit 1
}

Write-Host "[*] Selected backup: $($selectedBackup.Name)" -ForegroundColor Green
$confirm = Read-Host "Are you sure you want to restore this database? This will overwrite the current database! (y/N)"
if ($confirm -ne "y" -and $confirm -ne "yes") {
    Write-Host "Restoration cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host "[*] Copying dump file to database container..." -ForegroundColor Yellow
docker cp $dumpFile "my-photo-gallery-immich-postgres:/tmp/immich-postgres.dump"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to copy dump file to container."
    exit 1
}

try {
    Write-Host "[*] Terminating existing connections to the database..." -ForegroundColor Yellow
    docker exec my-photo-gallery-immich-postgres psql -U postgres -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = 'immich' AND pid <> pg_backend_pid();" | Out-Null

    Write-Host "[*] Dropping database immich..." -ForegroundColor Yellow
    docker exec my-photo-gallery-immich-postgres dropdb -U postgres --if-exists immich
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to drop database."
        exit 1
    }

    Write-Host "[*] Creating database immich..." -ForegroundColor Yellow
    docker exec my-photo-gallery-immich-postgres createdb -U postgres immich
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create database."
        exit 1
    }

    Write-Host "[*] Restoring database dump (this may take a moment)..." -ForegroundColor Yellow
    docker exec my-photo-gallery-immich-postgres pg_restore -U postgres -d immich --clean --if-exists /tmp/immich-postgres.dump
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Database restoration failed."
        exit 1
    }

    # Restarting Immich Server to pick up database changes
    Write-Host "[*] Restarting Immich server to apply changes..." -ForegroundColor Yellow
    docker compose restart immich-server
}
finally {
    Write-Host "[*] Cleaning up temporary files inside container..." -ForegroundColor Yellow
    docker exec my-photo-gallery-immich-postgres rm -f /tmp/immich-postgres.dump | Out-Null
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "   Database Restored Successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
