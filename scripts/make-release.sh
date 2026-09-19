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

if [[ ! -f .env.example ]]; then
  echo "release error: .env.example is missing from the project root" >&2
  exit 1
fi

rm -f "$OUT"

# اضغط كل الشجرة ماعدا المستثنيات الأمنية
zip -r -q "$OUT" . \
  -x '.git/*' \
  -x '*/.dart_tool/*' -x '*/.gradle/*' -x '*/build/*' \
  -x '*/local.properties' -x '*/key.properties' -x '*.keystore' -x '*.jks' \
  -x '*/__pycache__/*' -x '*.pyc' \
  -x './.env' -x '*/.env' \
  -x './.secret' -x '*/.secret' \
  -x '*.db' -x '*.db-wal' -x '*.db-shm' \
  -x './data/*' -x 'data/*' \
  -x './node_modules/*' -x '*/node_modules/*' \
  -x "$(basename "$OUT")"

# Read archive entries robustly: zip may print ./name instead of name.
archive_has_entry() {
  local wanted="$1"
  unzip -Z1 "$OUT" | awk -v wanted="$wanted" '{ sub(/^\.\//, ""); if ($0 == wanted) found=1 } END { exit(found ? 0 : 1) }'
}

# شيل مدخل data/ فقط لو موجود؛ ممنوع رسالة zip error المضللة في إصدار ناجح.
if archive_has_entry 'data/'; then
  zip -q -d "$OUT" 'data/' >/dev/null 2>&1 || true
fi

if ! archive_has_entry '.env.example'; then
  # Add the template explicitly from the project root if the recursive pass
  # omitted dotfiles. The archive check above accepts only the root entry.
  (cd "$ROOT" && zip -q "$OUT" '.env.example')
fi
if ! archive_has_entry '.env.example'; then
  echo "release error: .env.example was not included" >&2
  exit 1
fi

echo "release -> $OUT"
