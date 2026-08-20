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

# محافظت: اگه پوشه هرمس اصلاً وجود ندارد یا .env ندارد، آپلود نکن (جلوی پاک شدن بکاپ قبلی)
if [ ! -d "$HERMES_HOME" ]; then
  echo "❌ $HERMES_HOME وجود ندارد — آپلود انجام نشد (بکاپ قبلی دست‌نخورده ماند)"
  exit 1
fi
if [ ! -f "$HERMES_HOME/.env" ]; then
  echo "⚠️ .env در $HERMES_HOME پیدا نشد — احتمال بکاپ ناقص. آپلود انجام نشد."
  exit 1
fi

TMP="$(mktemp -d)"
BACKUP="$TMP/hermes-backup.zip"

echo ">> گرفتن بکاپ با hermes backup ..."
hermes backup -o "$BACKUP"

# محافظت ۲: بکاپ باید حداقل چند کیلوبایت باشد (اگه خراب/خالی بود، آپلود نکن)
MIN_BYTES=50000
ACTUAL=$(stat -c%s "$BACKUP")
if [ "$ACTUAL" -lt "$MIN_BYTES" ]; then
  echo "❌ بکاپ مشکوکاً کوچک است ($ACTUAL bytes < $MIN_BYTES) — آپلود انجام نشد"
  exit 1
fi

echo ">> آپلود روی ورکر (جایگزین نسخه قبلی) ..."
if curl -fsSL -X PUT "$WORKER_URL/backup" -H "x-backup-key: $WORKER_KEY" --data-binary @"$BACKUP"; then
  echo "✅ بکاپ آپلود شد: $(du -h "$BACKUP" | cut -f1)"
else
  echo "❌ آپلود بکاپ شکست خورد (بکاپ قبلی روی ورکر دست‌نخورده ماند)"
  exit 1
fi
