#!/usr/bin/env bash
# =============================================================
# rebuild_from_raw.sh — Chạy lại toàn bộ transform TỪ RAW có sẵn
#
# KHÔNG gọi Wayfair API — chỉ dựng lại staging → master → fact → mart
# từ dữ liệu raw đang có trong BigQuery.
#
# Dùng khi:
#   • Đổi cấu trúc SQLX (vd tách cha-con) → cần build lại từ đầu.
#   • Bảng master (incremental) cần FULL REFRESH để nạp lại toàn bộ raw.
#
# --full-refresh: bỏ qua điều kiện incremental (_loaded_at > MAX), rebuild
# master từ TẤT CẢ raw. Đây chính là "reset state" của lớp Dataform —
# state incremental của Dataform nằm ngay trong data bảng (MAX(_loaded_at)).
#
# Cách dùng:
#   ./rebuild_from_raw.sh dev              # full refresh tất cả wayfair (dev)
#   ./rebuild_from_raw.sh prod             # prod
#   ./rebuild_from_raw.sh dev staging      # chỉ tới lớp staging
#   ./rebuild_from_raw.sh dev master       # chỉ tới lớp master
#
# Yêu cầu: npm install (@dataform/core 3.0.0) + Dataform CLI toàn cục,
#   ADC: gcloud auth application-default login  (hoặc dataform init-creds)
#
# ⚠️ Dataform core 3.0.10 có bug full-refresh với incremental (issue #1914).
#    workflow_settings.yaml đang ghim 3.0.0 nên OK. Nếu nâng cấp, tránh 3.0.10.
# =============================================================
set -euo pipefail
cd "$(dirname "$0")/.."   # về thư mục gốc Dataform repo

ENVIRONMENT="${1:-dev}"
LAYER="${2:-all}"

case "$ENVIRONMENT" in
  dev)  DB="allforwood-dev" ;;
  prod) DB="allforwood" ;;
  *) echo "Usage: $0 [dev|prod] [all|staging|master|fact|mart]"; exit 1 ;;
esac

# CLI dùng --tags lặp lại cho từng tag (KHÔNG dùng dấu phẩy).
# Tất cả action đều có tag 'wayfair'; thêm tag lớp nếu muốn giới hạn.
TAG_ARGS=(--tags wayfair)
case "$LAYER" in
  all)     : ;;                                  # chỉ 'wayfair' = chạy hết
  staging) TAG_ARGS+=(--tags staging) ;;
  master)  TAG_ARGS+=(--tags master) ;;
  fact)    TAG_ARGS+=(--tags fact) ;;
  mart)    TAG_ARGS+=(--tags mart) ;;
  *) echo "layer phải là all|staging|master|fact|mart"; exit 1 ;;
esac

echo "==> Rebuild từ raw | env=$ENVIRONMENT (project $DB) | layer=$LAYER"
echo ""

# 1) Cài deps nếu chưa có
[ -d node_modules ] || { echo "==> npm install"; npm install; }

# 2) Compile để bắt lỗi sớm
echo "==> dataform compile"
dataform compile

# 3) Run full-refresh, override project qua --default-database
#    --include-deps: kéo theo dependency để đảm bảo thứ tự raw→staging→master→fact
echo "==> dataform run --full-refresh (project=$DB)"
dataform run \
  --default-database "$DB" \
  --default-location US \
  --full-refresh \
  --include-deps \
  "${TAG_ARGS[@]}"

echo ""
echo "==> Xong. Kiểm tra:"
echo "    bq ls --project_id=$DB afw_wayfair_master"
echo "    bq ls --project_id=$DB afw_wayfair_fact"
