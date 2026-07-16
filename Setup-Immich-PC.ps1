[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Immich Server Portability Setup Tool" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verify Docker is running
Write-Host "[*] Checking Docker status..." -ForegroundColor Yellow
& docker info > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker is not running. Please start/reset Docker Desktop first."
    exit 1
}
Write-Host "[+] Docker is running." -ForegroundColor Green

# 2. Verify shared mount directory exists
Write-Host "[*] Verifying shared mount directory exists..." -ForegroundColor Yellow
if (!(Test-Path -Path "rclone-shared-mount")) {
    New-Item -ItemType Directory -Force -Path "rclone-shared-mount" | Out-Null
}
Write-Host "[+] Shared mount directory ready (.\rclone-shared-mount)." -ForegroundColor Green

# 3. Clean up legacy Docker Rclone plugin (if exists)
Write-Host "[*] Checking for legacy Docker rclone plugin..." -ForegroundColor Yellow
$plugin = docker plugin ls --format '{{.Name}}' | Where-Object { $_ -eq "rclone:latest" }
if ($plugin) {
    Write-Host "[*] Removing legacy plugin to prevent system deadlocks..." -ForegroundColor Yellow
    docker plugin disable -f rclone > $null 2>&1
    docker plugin rm -f rclone > $null 2>&1
}
Write-Host "[+] Legacy plugin cleaned up." -ForegroundColor Green

# 4. Register Daily Backup Task Scheduler
Write-Host "[*] Registering Daily Backup Task Scheduler..." -ForegroundColor Yellow
$backupScript = Join-Path $PSScriptRoot "scripts\Backup-Immich.ps1"
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$backupScript`""
$trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Register-ScheduledTask -TaskName 'Immich Daily Backup' -Action $action -Trigger $trigger -Description 'Backup Immich database daily to local project folder' -User $currentUser -Force | Out-Null
Write-Host "[+] Daily backup registered at 2:00 AM under user: $currentUser" -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "   Setup Completed Successfully!" -ForegroundColor Green
Write-Host "   Run 'docker compose up -d' to start." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
