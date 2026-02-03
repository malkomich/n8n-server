# n8n Workflow Automation Server (Self-Hosted, HTTPS, IP-Based)

This repository provides a **clean, reproducible, error-free setup** to run **n8n** 24/7 using **Docker Compose**, **PostgreSQL**, **Nginx (HTTPS)** and **Google Drive backups via rclone**, exposed **publicly via IP** (no domain required).

The setup is designed for **UNIX servers** (Debian / Ubuntu / Raspberry Pi OS) and **macOS / UNIX clients**.

---

## 1. System Requirements

- **Privileges:** sudo access
- **Network:**
  - Port `35678/TCP` open on router (WAN → LAN)
  - No CGNAT (must have a real public IPv4)
- **Disk:** ≥ 5 GB free
- **Time:** Correct system clock (NTP enabled)

---

## 2. Docker & Docker Compose Installation (Server)

Install Docker Engine and Compose plugin:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Allow Docker without sudo:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

---

## 3. Environment Configuration (.env)

Create `.env` in the project root, with the keys defined in `.env.template`, and the right values for each secret.

IMPORTANT:
- **Do NOT use the `$` character** in passwords or keys.
- Values are injected directly into Docker.

---

## 4. HTTPS Certificates (Self-Signed, IP-Based)

Certificates are stored **outside the project** for security.

Create certificates directory:
```bash
mkdir -p ~/certs
```

Generate certificate for your public IP:
```bash
openssl req -x509 -nodes -days 730 -newkey rsa:2048 \
  -keyout ~/certs/n8n.key \
  -out ~/certs/n8n.crt \
  -subj "/CN=81.32.186.246"
```

Files created:
- `~/certs/n8n.key`
- `~/certs/n8n.crt`

---

## 5. Permissions (Mandatory)

Fix volume ownership before first start:

```bash
sudo mkdir -p ./data/n8n ./data/postgres
sudo chown -R 1000:1000 ./data/n8n
sudo chown -R 999:999 ./data/postgres
```

---

## 6. (Optional) Firewall Configuration (UFW)

If UFW is enabled, explicitly allow the required ports.

Install and enable UFW (if not already enabled):
```bash
sudo apt install -y ufw
sudo ufw enable
```

Allow SSH (recommended before enabling):
```bash
sudo ufw allow ssh
```

Allow HTTPS entry point:
```bash
sudo ufw allow 35678/tcp
```

Allow local PostgreSQL (Docker internal use):
```bash
sudo ufw allow from 172.16.0.0/12 to any port 5432
```

Verify rules:
```bash
sudo ufw status
```

---

## 7. Start the Server

```bash
docker compose down
docker compose up -d
```

Verify:
```bash
docker compose ps
docker compose logs -f n8n
docker compose logs -f nginx
```

Local test (server):
```bash
curl -kI https://127.0.0.1:35678
```

---

## 8. Router Configuration

Create **one** port forwarding rule:

- **WAN Port:** 35678
- **LAN Port:** 35678
- **Protocol:** TCP
- **Destination IP:** n8n server local IP (e.g. `192.168.1.39`)

---

## 9. Access

- **LAN:** https://192.168.1.39:35678
- **Public:** https://81.32.186.246:35678

Browser will show a **certificate warning** (expected). Accept the exception.

---

## 10. Google Drive Backups with rclone

Install rclone:
```bash
sudo apt install -y rclone
```

Configure Google Drive remote:
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

---

## 11. Recommended Backup Strategy

- PostgreSQL dump (daily)
- `data/n8n` archive
- Upload via rclone to Google Drive
- Keep local retention ≤ 14 days

---

## 12. Notes

- HTTPS is handled **only by Nginx**
- n8n runs internally over HTTP
- No domain required
- No interactive setup required after this
