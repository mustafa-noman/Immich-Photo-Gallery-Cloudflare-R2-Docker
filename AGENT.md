# AGENT.md — Immich Docker Setup on Windows Server

## Start Here

Before doing anything, run the rules in this exact order:

```text
R0
R1
```

After R0 and R1 are completed, continue with the Immich Docker setup below.

---

## Goal

Set up Immich photo/video backup server on a Windows Server using the user's local Docker environment with Docker Compose.

This setup is for a private/family photo and video gallery with mobile backup support.

Final target architecture:

```text
Windows Server / Local Machine
│
├── Local Docker / Docker Compose
│   ├── immich-server
│   ├── immich-machine-learning
│   ├── redis
│   └── postgres
│
├── Local Disk
│   ├── PostgreSQL Docker volume
│   ├── Immich upload/cache/library folder
│   └── backup/export folder
│
└── Optional Cloud Storage Later
    └── Cloudflare R2 / S3-compatible object storage
```

Important: use the user's local Docker environment as the main setup. Do not use a remote Docker host, cloud Docker service, IIS hosting, or native Windows services for Immich.

---

## R0 — Safety Rules

- Do not delete existing server files unless explicitly asked.
- Do not touch existing IIS websites.
- Do not touch existing PostgreSQL databases unless explicitly asked.
- Do not expose Immich publicly before admin user setup is complete.
- Do not store PostgreSQL database files in Cloudflare R2, S3, SMB network share, or slow external storage.
- Keep PostgreSQL data in a Docker volume or local SSD path.
- Always create backups before changing production configuration.
- Use PowerShell commands for Windows Server.
- Keep all commands copy/paste ready.
- Prefer the official Immich Docker Compose release files.

---

## R1 — Environment Check

Run these commands first in PowerShell as Administrator:

```powershell
systeminfo
wsl --status
docker version
docker compose version
```

Check if virtualization is enabled:

```powershell
systeminfo | Select-String "Hyper-V Requirements"
```

Expected:

```text
Virtualization Enabled In Firmware: Yes
Second Level Address Translation: Yes
```

If Docker is not installed locally, install Docker Desktop or Docker Engine with WSL2 support on this same Windows machine.

For this setup, always use local Docker context. Do not deploy to a remote Docker host unless the user explicitly asks later.

Check Docker context:

```powershell
docker context ls
docker context use default
```

For Windows Server, prefer Linux containers, not Windows containers.

---

## Recommended Folder Structure

Use `E:` drive if available on the local Windows machine.

```powershell
New-Item -ItemType Directory -Force -Path "E:\Docker\immich"
New-Item -ItemType Directory -Force -Path "E:\Immich\library"
New-Item -ItemType Directory -Force -Path "E:\Immich\backup"
New-Item -ItemType Directory -Force -Path "E:\Immich\import"
```

Folder purpose:

```text
E:\Docker\immich     = docker-compose.yml and .env
E:\Immich\library    = uploaded photos/videos and Immich media files
E:\Immich\backup     = backup output
E:\Immich\import     = temporary import folder
```

---

## Step 1 — Download Official Immich Compose Files

Go to the Immich Docker folder:

```powershell
cd E:\Docker\immich
```

Download official files:

```powershell
Invoke-WebRequest -Uri "https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml" -OutFile "docker-compose.yml"
Invoke-WebRequest -Uri "https://github.com/immich-app/immich/releases/latest/download/example.env" -OutFile ".env"
```

Do not use a random compose file from blogs or old GitHub examples.

---

## Step 2 — Update `.env`

Open `.env`:

```powershell
notepad .env
```

Set/update these values:

```env
UPLOAD_LOCATION=E:/Immich/library
DB_DATA_LOCATION=immich_postgres_data
TZ=Asia/Dhaka
IMMICH_VERSION=release
DB_PASSWORD=CHANGE_THIS_TO_A_STRONG_PASSWORD
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
```

Important notes:

- `UPLOAD_LOCATION` can be a Windows path using forward slashes.
- `DB_DATA_LOCATION=immich_postgres_data` should use a Docker volume style value for safety.
- Do not use a network share for the database.
- Use a strong database password.

---

## Step 3 — Confirm Compose Uses Docker Volume for PostgreSQL

Open `docker-compose.yml`:

```powershell
notepad docker-compose.yml
```

Make sure the database service stores data safely.

Preferred pattern:

```yaml
volumes:
  - ${DB_DATA_LOCATION}:/var/lib/postgresql/data
```

And at the bottom, make sure the named volume exists if needed:

```yaml
volumes:
  immich_postgres_data:
```

If the official compose file already handles this correctly, do not over-edit it.

---

## Step 4 — Start Immich

Run:

```powershell
docker compose up -d
```

Check containers:

```powershell
docker ps
```

Check logs:

```powershell
docker compose logs -f
```

Immich should become available at:

```text
http://SERVER-IP:2283
```

Local server test:

```text
http://localhost:2283
```

---

## Step 5 — Create Admin User

Open Immich in browser:

```text
http://localhost:2283
```

Create the first admin account.

Do not expose the site publicly until this is done.

---

## Step 6 — Windows Firewall Rule

Allow port 2283 only if needed:

```powershell
New-NetFirewallRule -DisplayName "Immich Web 2283" -Direction Inbound -Protocol TCP -LocalPort 2283 -Action Allow
```

If using a reverse proxy, expose only 80/443 publicly and keep 2283 private.

---

## Step 7 — Public Access Options

Recommended options:

```text
Option A: Cloudflare Tunnel
Option B: Nginx Proxy Manager in Docker
Option C: IIS ARR reverse proxy
Option D: Direct port 2283, only for temporary testing
```

Preferred for Windows Server:

```text
Cloudflare Tunnel
```

Reason:

- No need to open extra inbound ports.
- Easier SSL.
- Safer for home/VPS setups.

Example target service:

```text
http://localhost:2283
```

---

## Step 8 — Mobile App Setup

Install Immich mobile app on Android/iPhone.

Server URL examples:

```text
Local:  http://SERVER-IP:2283
Public: https://photos.yourdomain.com
```

Enable backup from the mobile app after login.

Recommended mobile settings:

```text
- Enable background backup
- Select camera folder
- Enable video backup if needed
- Keep app battery optimization unrestricted
- Test with 5-10 photos first
```

---

## Step 9 — Backup Plan

Minimum backup plan:

```text
1. PostgreSQL backup
2. Immich library backup
3. docker-compose.yml backup
4. .env backup
```

Create backup folder:

```powershell
New-Item -ItemType Directory -Force -Path "E:\Immich\backup\manual"
```

Database dump command:

```powershell
docker exec immich_postgres pg_dump -U postgres immich > E:\Immich\backup\manual\immich-db-backup.sql
```

If the database container name is different, find it:

```powershell
docker ps --format "table {{.Names}}\t{{.Image}}"
```

Copy config files:

```powershell
Copy-Item "E:\Docker\immich\docker-compose.yml" "E:\Immich\backup\manual\docker-compose.yml" -Force
Copy-Item "E:\Docker\immich\.env" "E:\Immich\backup\manual\.env" -Force
```

Important: do not treat Immich itself as the only backup. Immich is a photo management app, but you still need backup copies.

---

## Step 10 — Updating Immich

Go to compose folder:

```powershell
cd E:\Docker\immich
```

Backup first:

```powershell
docker exec immich_postgres pg_dump -U postgres immich > E:\Immich\backup\manual\immich-db-before-update.sql
```

Pull latest images:

```powershell
docker compose pull
```

Recreate containers:

```powershell
docker compose up -d
```

Check logs:

```powershell
docker compose logs -f
```

---

## Step 11 — Cloudflare R2 / S3-Compatible Object Storage

Use Cloudflare R2 for Immich original photos/videos if the user wants cloud bucket storage.

Use:

```text
Cloudflare R2 = original photo/video object storage
Local Docker volume = PostgreSQL database
Local disk/Docker volume = cache, thumbnails, temp files
```

Do not use Cloudflare Images for Immich storage. Use Cloudflare R2.

Default R2 bucket storage class:

```text
Standard
```

Do not use Infrequent Access / Archive style storage for the active Immich media library.

### R2 Values Needed

Ask the user to collect these from Cloudflare R2, but never ask them to paste the secret key into chat. The user should paste the secret only into the local `.env` file.

```env
R2_BUCKET_NAME=immich-media
R2_ACCOUNT_ID=CHANGE_THIS_ACCOUNT_ID
R2_ACCESS_KEY_ID=CHANGE_THIS_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY=CHANGE_THIS_SECRET_ACCESS_KEY_LOCAL_ONLY
R2_REGION=auto
R2_ENDPOINT=https://CHANGE_THIS_ACCOUNT_ID.r2.cloudflarestorage.com
```

Where to find/create them:

```text
Bucket Name: Cloudflare Dashboard -> R2 -> Buckets
Account ID: Cloudflare Dashboard -> R2 -> Overview
Access Key ID: R2 -> Manage R2 API Tokens -> Create API Token
Secret Access Key: shown once after token creation
Region: auto
Endpoint: https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

Recommended bucket visibility:

```text
Private bucket
```

Do not make the R2 bucket public unless the user explicitly needs public direct file delivery later. Immich should handle authentication.

### R2 Permission Recommendation

Create an R2 API token with access limited to the Immich bucket where possible. Required operations should include read/write/list/delete object access for that bucket.

Use bucket name like:

```text
immich-media
```

### Important R2 Rules

Never put these into R2:

```text
- PostgreSQL data
- Docker volumes
- Redis data
- temporary app cache
- thumbnails/cache unless Immich explicitly supports and requires it
```

Good R2 use:

```text
- original photos
- original videos
- large media objects
```

Still keep a separate backup. R2 is storage, not a full backup strategy.

### Immich Object Storage Setup Approach

First complete the normal local Docker Immich setup. Confirm uploads work locally. Then configure object storage from the Immich admin/server settings or supported Immich configuration method for the installed version.

Use these S3-style values when configuring Cloudflare R2:

```text
Provider: S3 compatible
Endpoint: https://<ACCOUNT_ID>.r2.cloudflarestorage.com
Region: auto
Bucket: immich-media
Access Key ID: from Cloudflare R2 API token
Secret Access Key: from Cloudflare R2 API token
Path Style: enabled if Immich asks for it
SSL: enabled
Public access: disabled/private
```

If Immich version requires environment variables or a config file for object storage, update the local `.env` with placeholder values first and tell the user exactly where to paste real secrets locally.

---

## Useful Commands

Start:

```powershell
cd E:\Docker\immich
docker compose up -d
```

Stop:

```powershell
cd E:\Docker\immich
docker compose down
```

Restart:

```powershell
cd E:\Docker\immich
docker compose restart
```

Logs:

```powershell
cd E:\Docker\immich
docker compose logs -f
```

Container status:

```powershell
docker ps
```

Disk usage:

```powershell
docker system df
```

Immich folder size:

```powershell
Get-ChildItem "E:\Immich\library" -Recurse | Measure-Object -Property Length -Sum
```

---

## Troubleshooting

### Docker command not found

Install Docker Desktop / Docker Engine and restart PowerShell.

### WSL error

Run:

```powershell
wsl --install
wsl --update
wsl --status
```

Restart server after WSL install/update.

### Port already used

Check port 2283:

```powershell
netstat -ano | findstr :2283
```

### Immich not opening

Check containers:

```powershell
docker ps
```

Check logs:

```powershell
cd E:\Docker\immich
docker compose logs -f
```

### Database error

Do not delete database volume.

Check logs:

```powershell
docker compose logs database
```

or:

```powershell
docker ps --format "table {{.Names}}\t{{.Image}}"
```

Then use the real database container name.

---

## Local Docker Rule

This project must use the user's local Docker installation.

```text
Use local Docker only.
Do not assume VPS Docker.
Do not use remote Docker context.
Do not use IIS to host Immich.
Do not use the existing Windows PostgreSQL unless the user asks later.
```

Before running compose commands, confirm Docker is local:

```powershell
docker context ls
docker context use default
docker info
```

The expected working folder is local:

```text
E:\Docker\immich
```

---

## Final Notes for Codex

When implementing or modifying this setup:

- Keep the setup simple.
- Use official Immich Docker Compose files.
- Use the local Docker context only.
- Use PowerShell commands only.
- Do not convert this into IIS hosting.
- Do not use existing PostgreSQL unless explicitly requested later.
- Prefer Docker-managed PostgreSQL for Immich.
- Keep the database on local disk or Docker volume.
- Make every command copy/paste ready.
- After each major step, provide the exact next command.
