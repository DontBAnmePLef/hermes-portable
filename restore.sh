#!/usr/bin/env bash
# hermes-portable: restore state from Cloudflare Worker (R2) then start gateway
# متغیرها از secrets گیت‌هاب میاد:
#   WORKER_URL  - آدرس ورکر
#   WORKER_KEY  - رمز اشتراکی (x-backup-key)
#   HOME برابر با خانه کاربر (مثلا /home/cynetadmin)
set -e

WORKER_URL="${WORKER_URL:?WORKER_URL secret لازم است}"
WORKER_KEY="${WORKER_KEY:?WORKER_KEY secret لازم است}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

echo "=========== [1/4] دانلود بکاپ از ورکر ==========="
TMP="$(mktemp -d)"
if ! curl -fsSL "$WORKER_URL/backup" -H "x-backup-key: $WORKER_KEY" -o "$TMP/hermes-backup.zip"; then
  echo "❌ دانلود بکاپ شکست خورد. آیا WORKER_URL و WORKER_KEY درسته؟"
  exit 1
fi
echo "✅ بکاپ دانلود شد: $(du -h "$TMP/hermes-backup.zip" | cut -f1)"

echo "=========== [2/4] باز کردن در $HERMES_HOME ==========="
mkdir -p "$HERMES_HOME"
# بکاپ با hermes backup ساخته شده -> مسیرها نسبت به .hermes هست
# (فایل درون زیپ در پوشه .hermes/ قرار داره، پس مستقیم باز میشه)
cd "$HERMES_HOME"
unzip -o "$TMP/hermes-backup.zip" >/dev/null
# اگر زیپ درون پوشه .hermes بود، یک سطح بالاتر بیار
if [ -d "$HERMES_HOME/.hermes" ]; then
  mv "$HERMES_HOME/.hermes/"* "$HERMES_HOME/" 2>/dev/null || true
  rmdir "$HERMES_HOME/.hermes" 2>/dev/null || true
fi

if [ -f "$HERMES_HOME/.env" ]; then
  echo "✅ .env پیدا شد — هویت/توکن تلگرام از بکاپ برمی‌گرده"
else
  echo "⚠️ .env پیدا نشد — باید دستی hermes setup بزنی"
fi

echo "=========== [3/4] نصب Hermes Agent ==========="
if ! command -v hermes &>/dev/null; then
  echo "نصب هرمس..."
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
else
  echo "هرمس از قبل نصب بود: $(hermes --version 2>/dev/null || echo unknown)"
fi

echo "=========== [4/4] استارت گیتوی ==========="
# اطمینان از دسترسی فایل‌ها برای کاربر جاری
chmod 600 "$HERMES_HOME/.env" 2>/dev/null || true
cd "$HOME"
nohup hermes gateway start > /tmp/hermes.log 2>&1 &
sleep 6
if pgrep -f "hermes gateway" >/dev/null; then
  echo "✅ هرمس دارد اجرا میشود (دقیقاً همون هویت قبلی)"
else
  echo "❌ استارت نشد. لاگ:"
  tail -30 /tmp/hermes.log
  exit 1
fi
