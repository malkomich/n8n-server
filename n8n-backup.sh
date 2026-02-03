#!/usr/bin/env bash
set -euo pipefail

TS=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$HOME/.n8n/backups"
mkdir -p "$BACKUP_DIR"

# 1) Postgres dump
docker exec -t $(docker ps -qf "name=postgres") pg_dump -U "$DB_POSTGRESDB_USER" "$DB_POSTGRESDB_DATABASE" \
  > "$BACKUP_DIR/postgres_$TS.sql"

# 2) Compress n8n data (from mounted directory)
tar -czf "$BACKUP_DIR/n8n_data_$TS.tar.gz" -C "$(pwd)" data/n8n

# 3) Upload to Google Drive (remote: gdrive)
rclone copy "$BACKUP_DIR" gdrive:n8n-backups --include "*$TS*"

# 4) Local cleanup (default: 14 days expiration)
find "$BACKUP_DIR" -type f -mtime +14 -delete
