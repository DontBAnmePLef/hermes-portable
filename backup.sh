#!/usr/bin/env bash
# آپلود بکاپ ~/.hermes روی Cloudflare Worker قبل از مرگ سرور
# متغیرها:
#   WORKER_URL - آدرس ورکر
#   WORKER_KEY - رمز اشتراکی (x-backup-key)
#   HERMES_HOME - مسیر (مثلا /home/cynetadmin/.hermes)
set -e

WORKER_URL="${WORKER_URL:?WORKER_URL لازم است}"
WORKER_KEY="${WORKER_KEY:?WORKER_KEY لازم است}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

echo "=========== [AUTO-BACKUP] قبل از مرگ سرور ==========="
TMP="$(mktemp -d)"
BACKUP="$TMP/hermes-backup.zip"

echo ">> گرفتن بکاپ با hermes backup ..."
hermes backup -o "$BACKUP"

echo ">> آپلود روی ورکر (جایگزین نسخه قبلی) ..."
if curl -fsSL -X PUT "$WORKER_URL/backup" -H "x-backup-key: $WORKER_KEY" --data-binary @"$BACKUP"; then
  echo "✅ بکاپ آپلود شد: $(du -h "$BACKUP" | cut -f1)"
else
  echo "❌ آپلود بکاپ شکست خورد (ادامه میدهد)"
  exit 1
fi
