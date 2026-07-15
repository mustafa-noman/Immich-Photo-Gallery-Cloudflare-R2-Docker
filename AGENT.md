# AGENT.md — Immich Docker Setup on Windows Server

## Start Here

Before doing anything, run the rules in this exact order:

```text
R0
R1
```

After R0 and R1 are completed, continue with the Immich setup guide below.

---

## Goal

Set up an Immich photo/video gallery server on a Windows Server using Docker Desktop (WSL2 backend) with Cloudflare R2 as the primary media library storage via the official Docker Rclone Volume Plugin.

---

## R0 — Safety Rules

- Do not delete existing server files unless explicitly asked.
- Keep PostgreSQL database files local (in a named Docker volume). Do not place DB files on network shares or cloud drives.
- Keep all commands copy/paste ready.
- Use PowerShell commands for Windows Server.

---

## Step-by-Step Server Setup from Scratch

Follow these steps directly on the Windows Server:

### Step 1 — Create Folders on Windows
Run in PowerShell as Administrator:
```powershell
New-Item -ItemType Directory -Force -Path "D:\Immich\backup"
New-Item -ItemType Directory -Force -Path "D:\Immich\rclone-config"
```

### Step 2 — Create the Rclone Config File
On the server, run:
```powershell
notepad "D:\Immich\rclone-config\rclone.conf"
```
Paste the following (replace with your actual Cloudflare R2 credentials) and save:
```ini
[my-r2]
type = s3
provider = Cloudflare
access_key_id = YOUR_ACCESS_KEY_ID
secret_access_key = YOUR_SECRET_ACCESS_KEY
endpoint = https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
region = auto
```

### Step 3 — Install the Rclone Docker Volume Plugin
Run in PowerShell:
```powershell
# 1. Create native Linux cache folder inside the Docker WSL2 VM
wsl -d docker-desktop -u root mkdir -p /tmp/rclone-cache

# 2. Install the plugin using host-mapped config and native VM cache paths
docker plugin install rclone/docker-volume-rclone:amd64 --alias rclone --grant-all-permissions config=/run/desktop/mnt/host/d/Immich/rclone-config cache=/tmp/rclone-cache
```

### Step 4 — Setup Project Files
Go to your project directory (e.g., `D:\_Projects\My Photo Gallery Immich Server`):
```powershell
Set-Location "D:\_Projects\My Photo Gallery Immich Server"
```
Ensure your `.env` contains:
```env
UPLOAD_LOCATION=D:/Immich/library
DB_DATA_LOCATION=postgres-data
TZ=Asia/Dhaka
IMMICH_VERSION=v3
DB_PASSWORD=YourStrongDatabasePasswordHere
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
```

Ensure your `docker-compose.yml` matches:
```yaml
name: my-photo-gallery-immich

services:
  immich-server:
    container_name: my-photo-gallery-immich-server
    image: ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-v3}
    volumes:
      - immich-library:/data
      - /etc/localtime:/etc/localtime:ro
    env_file:
      - .env
    ports:
      - "127.0.0.1:6001:2283"
    depends_on:
      - redis
      - database
    restart: always
    healthcheck:
      disable: false

  immich-machine-learning:
    container_name: my-photo-gallery-immich-machine-learning
    image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-v3}
    volumes:
      - model-cache:/cache
    env_file:
      - .env
    restart: always
    healthcheck:
      disable: false

  redis:
    container_name: my-photo-gallery-immich-redis
    image: docker.io/valkey/valkey:9@sha256:3b55fbaa0cd93cf0d9d961f405e4dfcc70efe325e2d84da207a0a8e6d8fde4f9
    healthcheck:
      test: redis-cli ping || exit 1
    restart: always

  database:
    container_name: my-photo-gallery-immich-postgres
    image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_DB: ${DB_DATABASE_NAME}
      POSTGRES_INITDB_ARGS: "--data-checksums"
    volumes:
      - ${DB_DATA_LOCATION}:/var/lib/postgresql/data
    ports:
      - "127.0.0.1:6002:5432"
    shm_size: 128mb
    restart: always
    healthcheck:
      disable: false

volumes:
  model-cache:
  postgres-data:
  immich-library:
    driver: rclone
    driver_opts:
      remote: "my-r2:my-photo-gallery-immich"
      vfs_cache_mode: "full"
```

### Step 5 — Start and Validate
Start the stack:
```powershell
docker compose pull
docker compose up -d
```
Test health:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Test-Immich.ps1
```

---

## Public Access & Mobile App

### 1. Cloudflare Tunnel
Add a public route inside your Cloudflare Zero Trust Dashboard:
* **Service**: `HTTP`
* **URL**: `localhost:6001`
* **Domain**: `photos.yourdomain.com`

### 2. Mobile App Setup
* Install the Immich Mobile App.
* Log in using your public URL (e.g., `https://photos.yourdomain.com`).
* Enable background backup.
