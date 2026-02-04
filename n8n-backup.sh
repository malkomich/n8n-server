#!/usr/bin/env bash
set -euo pipefail

# --------- CONFIG ----------
PROJECT_DIR="$(pwd)"
ENV_FILE="$PROJECT_DIR/.env"
BACKUP_DIR="$HOME/.n8n/backups"
RCLONE_REMOTE="gdrive:n8n-backups"
mkdir -p "$BACKUP_DIR"
LOCAL_RETENTION_DAYS=14
REMOTE_RETENTION_DAYS=90
# ---------------------------

TS=$(date +"%Y-%m-%d_%H-%M-%S")
mkdir -p "$BACKUP_DIR"

# Load environment variables
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
else
  echo "ERROR: .env not found at $ENV_FILE" >&2
  exit 1
fi

# Sanity check required vars
: "${DB_POSTGRESDB_USER:?Missing DB_POSTGRESDB_USER in .env}"
: "${DB_POSTGRESDB_PASSWORD:?Missing DB_POSTGRESDB_PASSWORD in .env}"
: "${DB_POSTGRESDB_DATABASE:?Missing DB_POSTGRESDB_DATABASE in .env}"

cd "$PROJECT_DIR"

# 1) Postgres dump (use docker compose to target the correct container)
PG_DUMP_FILE="$BACKUP_DIR/postgres_${TS}.sql"
docker compose exec -T postgres \
  pg_dump -U "$DB_POSTGRESDB_USER" "$DB_POSTGRESDB_DATABASE" \
  > "$PG_DUMP_FILE"

# 2) Compress n8n data volume (host directory)
N8N_TAR_FILE="$BACKUP_DIR/n8n_data_${TS}.tar.gz"
tar -czf "$N8N_TAR_FILE" -C "$PROJECT_DIR" data/n8n

# 3) Upload to Google Drive (put backups in a dated folder)
REMOTE_DIR="$RCLONE_REMOTE/$TS"
rclone mkdir "$REMOTE_DIR"
rclone copy "$PG_DUMP_FILE" "$REMOTE_DIR"
rclone copy "$N8N_TAR_FILE" "$REMOTE_DIR"

# 4) Local cleanup
find "$BACKUP_DIR" -type f -mtime +"$LOCAL_RETENTION_DAYS" -delete

# 5) Remote cleanup (remove remote objects older than REMOTE_RETENTION_DAYS)
rclone delete "$RCLONE_REMOTE" --min-age "${REMOTE_RETENTION_DAYS}d" --rmdirs

echo "Backup OK: $TS"
