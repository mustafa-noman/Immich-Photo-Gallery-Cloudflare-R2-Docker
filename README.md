# My Photo Gallery — Immich

Private Immich server running on local Docker Desktop for Windows. Compose project name is `my-photo-gallery-immich`. Its PostgreSQL and Valkey services are isolated from existing Docker databases.

## Storage

- Media library: `E:\Immich\library`
- Database: Docker named volume `my-photo-gallery-immich_postgres-data`
- ML cache: Docker named volume `my-photo-gallery-immich_model-cache`
- Backups: `E:\Immich\backup`

Never use Immich as the only copy of photos. Keep database and media backups.

## Start and verify

```powershell
Set-Location "D:\My Photo Gallery Immich Server"
docker context show
docker compose config --quiet
docker compose pull
docker compose up -d
.\scripts\Test-Immich.ps1
```

Open `http://localhost:2283` and create the first admin account. Port 2283 binds only to localhost until Cloudflare Tunnel is configured.

## Backup

```powershell
Set-Location "D:\My Photo Gallery Immich Server"
.\scripts\Backup-Immich.ps1
```

This creates a PostgreSQL custom-format dump and copies Compose configuration into a timestamped folder under `E:\Immich\backup`. Back up `E:\Immich\library` separately to another disk or storage service.

## Update

```powershell
Set-Location "D:\My Photo Gallery Immich Server"
.\scripts\Backup-Immich.ps1
docker compose pull
docker compose up -d
.\scripts\Test-Immich.ps1
```

Read Immich release notes before updates. `IMMICH_VERSION=v2` tracks the current v2 release line.

## Stop

```powershell
docker compose down
```

Do not add `--volumes`; that would delete database/cache volumes.

## Cloudflare later

Finish local admin setup first. Then use Cloudflare Tunnel with origin `http://host.docker.internal:2283` when `cloudflared` runs in Docker, or `http://localhost:2283` when it runs directly on Windows. Keep R2 bucket private and secrets only in local `.env`.
