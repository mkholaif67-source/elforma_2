#!/usr/bin/env bash
# ============================================================
#  make-release.sh
#
#  بينشئ أرشيف مشاركة آمن للمشروع:
#    ✓ يضم التطبيق كامل (server.js, api, lib, app, public, mobile, scripts, test)
#    ✓ يضم قالب .env.example الآمن
#    ✗ مايضمّش أي أسرار (.env / .secret)
#    ✗ مايضمّش قاعدة بيانات حقيقية (*.db) ولا مجلد data/
#    ✗ مايضمّش node_modules ولا .git
#
#  الاستخدام: bash scripts/make-release.sh [مسار_الإخراج.zip]
# ============================================================
set -euo pipefail

OUT="${1:-release.zip}"
# حوّل مسار الإخراج لمسار مطلق قبل ما نغير المجلد
case "$OUT" in
  /*) : ;;
  *) OUT="$(pwd)/$OUT" ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

rm -f "$OUT"

# اضغط كل الشجرة ماعدا المستثنيات الأمنية
zip -r -q "$OUT" . \
  -x '.git/*' \
  -x './.env' -x '*/.env' \
  -x './.secret' -x '*/.secret' \
  -x '*.db' -x '*.db-wal' -x '*.db-shm' \
  -x './data/*' -x 'data/*' \
  -x './node_modules/*' -x '*/node_modules/*' \
  -x "$(basename "$OUT")"

# شيل مدخل data/ فقط لو موجود؛ ممنوع رسالة zip error المضللة في إصدار ناجح.
if unzip -Z1 "$OUT" | grep -qx 'data/'; then
  zip -q -d "$OUT" 'data/' >/dev/null 2>&1
fi

echo "release -> $OUT"
