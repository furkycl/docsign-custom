#!/usr/bin/env bash
#
# ═════════════════════════════════════════════════════════════════════════════
# docsign-custom — Günlük PostgreSQL Yedek Script'i
# ═════════════════════════════════════════════════════════════════════════════
#
# Bu script PostgreSQL veritabanının pg_dump çıktısını alır, gzip ile sıkıştırır
# ve /var/backups/docsign/ klasörüne kaydeder. Son 14 günü tutar, eskileri siler.
#
# Kullanım:
#   1. Bu script'i sunucuya kopyala: /opt/docsign-custom/scripts/backup.sh
#   2. Çalıştırma izni ver:           chmod +x /opt/docsign-custom/scripts/backup.sh
#   3. Cron job ekle (root olarak):
#        crontab -e
#        0 3 * * * /opt/docsign-custom/scripts/backup.sh >> /var/log/docsign-backup.log 2>&1
#
#   Her gece 03:00'da yedek alır.
#
# Restore:
#   1. Yedek dosyasını seç (örn. /var/backups/docsign/db-20260512.sql.gz)
#   2. Restore et:
#        gunzip < /var/backups/docsign/db-20260512.sql.gz | \
#          docker compose -f docker-compose.prod.yml exec -T postgres \
#          psql -U $POSTGRES_USER $POSTGRES_DB
#
# ═════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Konfigürasyon
PROJECT_DIR="${PROJECT_DIR:-/opt/docsign-custom}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/docsign}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# Hedef klasörü oluştur
mkdir -p "$BACKUP_DIR"

# .env.production'dan DB bilgilerini yükle
if [ -f "$PROJECT_DIR/.env.production" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env.production"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-docsign}"
POSTGRES_DB="${POSTGRES_DB:-docsign_production}"

echo "[$(date)] === docsign-custom yedek başlatıldı ==="
echo "[$(date)] DB: $POSTGRES_DB, kullanıcı: $POSTGRES_USER, hedef: $BACKUP_DIR"

# Yedek dosyası adı
BACKUP_FILE="$BACKUP_DIR/db-$TIMESTAMP.sql.gz"

# pg_dump → gzip
cd "$PROJECT_DIR"
docker compose -f docker-compose.prod.yml exec -T postgres \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --clean --if-exists \
  | gzip -9 > "$BACKUP_FILE"

# Dosya boyutunu logla
FILE_SIZE_HUMAN="$(du -h "$BACKUP_FILE" | cut -f1)"
echo "[$(date)] Yedek tamam: $BACKUP_FILE ($FILE_SIZE_HUMAN)"

# Eski yedekleri sil ($RETENTION_DAYS günden eski)
echo "[$(date)] $RETENTION_DAYS günden eski yedekler temizleniyor..."
find "$BACKUP_DIR" -name 'db-*.sql.gz' -mtime "+$RETENTION_DAYS" -print -delete

echo "[$(date)] === docsign-custom yedek tamamlandı ==="

# ─────────────────────────────────────────────────────────────────────
# OPSIYONEL: S3'e push (uncomment ve aws-cli kur)
# ─────────────────────────────────────────────────────────────────────
# if command -v aws &> /dev/null && [ -n "${S3_BACKUP_BUCKET:-}" ]; then
#   aws s3 cp "$BACKUP_FILE" "s3://$S3_BACKUP_BUCKET/$(basename "$BACKUP_FILE")"
#   echo "[$(date)] Yedek S3'e gönderildi: $S3_BACKUP_BUCKET"
# fi
