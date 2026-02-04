# n8n Workflow Automation Server (Self-Hosted, HTTPS)

This repository provides a **clean, production-ready setup** for **n8n** using **Docker Compose**, **PostgreSQL**, and **Nginx Proxy Manager (NPM)**. It includes **Google Drive backups via rclone**.

The setup is designed for **UNIX servers** (Debian / Ubuntu / Raspberry Pi OS).

---

## 1. System Requirements

- **Privileges:** sudo access.
- **Network & Port Forwarding:** You must configure your router's **Port Forwarding** (WAN → LAN) to point to your server's local IP for the following ports:
  - `80/TCP`: HTTP (Mandatory for SSL challenges).
  - `443/TCP`: HTTPS (Public access to services).
  - `81/TCP`: NPM Admin Panel (Optional, for remote management).
- **Software:** Docker Engine and Docker Compose plugin installed.

---

## 1. Environment Configuration (.env)

1. Create `.env` from `.env.template`.
2. Configure with new credentials and secure keys.
3. Set `PUBLIC_HOST=subdomain.yourdomain.com`.

IMPORTANT:
- **Do NOT use the `$` character** in passwords or keys.
- Values are injected directly into Docker.

Fix volume ownership:
```bash
sudo mkdir -p ./data/n8n ./data/postgres
sudo chown -R 1000:1000 ./data/n8n
sudo chown -R 999:999 ./data/postgres
```

---

## 1. Start the Server

```bash
docker compose down
docker compose up -d
```

Verify:
```bash
docker compose ps
docker compose logs -f n8n
docker compose logs -f nginx_proxy
```

---

## 1. SSL & Proxy Configuration (NPM)

1. Access the Admin Panel: `http://<SERVER_LOCAL_IP>:81`
2. **Add Proxy Host**:
   - **Domain Names:** `subdomain.yourdomain.com`
   - **Scheme:** `http`
   - **Forward Hostname:** `n8n` (internal docker service name)
   - **Forward Port:** `5678`
   - **Websockets Support:** Enabled.
3. **SSL Tab**:
   - Select **Request a new SSL Certificate**.
   - Enable **Force SSL** and **HTTP/2 Support**.
   - *Note:* Ensure your **Port Forwarding for port 80** is active, otherwise the certificate request will fail.

---

## 1. Access Points

- **n8n (Public):** `https://subdomain.yourdomain.com`
- **n8n (Local):** `http://<SERVER_LOCAL_IP>:5678`
- **pgAdmin (Local):** `http://<SERVER_LOCAL_IP>:8080`
- **NPM Admin Panel:** `http://<SERVER_LOCAL_IP>:81`

---

## 1. Google Drive Backups (rclone)

### Installation
```bash
sudo apt install -y rclone
```

### ConfigureGoogle Drive remote:
```bash
rclone config
```

Follow **exactly** these steps:
1. `n` → New remote
2. Name: `gdrive`
3. Storage: `Google Drive`
4. Client ID: **leave empty**
5. Client Secret: **leave empty**
6. Scope: `1` (Full access)
7. Root folder ID: **leave empty**
8. Service account: **leave empty**
9. Advanced config: `n`
10. Auto config: `n`
11. Open the provided URL **on your local machine (Mac or UNIX)**
12. Authorize Google Drive access
13. Paste the verification code back into the server terminal
14. Shared Drive: `n`
15. Confirm configuration: `y`

Official reference:
https://rclone.org/drive/#making-your-own-client-id

Verify:
```bash
rclone lsd gdrive:
rclone mkdir gdrive:n8n-backups
```

### Automated Backup Strategy (Cron)
1. Create the script `n8n-backup.sh` (included in this repository)
1. Schedule daily at 3 AM: `crontab -e`
"""bash
0 3 * * * /bin/bash ~/backup.sh
"""

---

## 1. Infrastructure Setup (DDNS)

To keep your domain pointing to a dynamic IP, install a DDNS updater:
```bash
go install github.com/qdm12/ddns-updater/cmd/ddns-updater@latest
mkdir -p ~/ddns/data && mv ~/go/bin/ddns-updater ~/ddns/
```

Create `~/ddns/data/config.json` with your provider's specific settings (refer to [ddns-updater docs](https://github.com/qdm12/ddns-updater)):

### Resilient Background Service
Create the service: `sudo nano /etc/systemd/system/ddns-updater.service`
```ini
[Unit]
Description=DDNS Updater
After=network-online.target
Wants=network-online.target

[Service]
User=<your_user>
WorkingDirectory=/home/<your_user>/ddns
ExecStart=/home/<your_user>/ddns/ddns-updater -datadir ./data
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```
Enable it: `sudo systemctl enable --now ddns-updater`

---

## 1. Notes

- **PostgreSQL** dump (daily)
- **NPM** managing all SSL renewals automatically.
- Backups uploaded via **rclone** to Google Drive
- Local backup retention ≤ 14 days
