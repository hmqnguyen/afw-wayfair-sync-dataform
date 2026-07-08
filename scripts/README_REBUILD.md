# Chạy đồng bộ lại từ RAW

Sau khi đổi cấu trúc SQLX (vd tách orders thành cha-con), cần dựng lại
staging → master → fact → mart từ raw có sẵn. KHÔNG gọi lại Wayfair API.

## Bước 1 — Dọn bảng cũ mồ côi (1 lần)

Cấu trúc orders đổi tên nên bảng cũ không còn dùng:

```bash
# Sửa <PROJECT> trong file thành allforwood-dev (hoặc allforwood) rồi:
sed 's/<PROJECT>/allforwood-dev/g' scripts/drop_legacy_tables.sql | \
  bq query --use_legacy_sql=false --location=US
```

Xóa: `stg_wayfair_orders`, `master_wayfair_orders` (tên số nhiều cũ).

## Bước 2 — Rebuild từ raw (full-refresh)

### Cách A — Dataform CLI (local)

```bash
npm install               # cài @dataform/core (1 lần)
./scripts/rebuild_from_raw.sh dev        # rebuild tất cả từ raw (dev)
./scripts/rebuild_from_raw.sh prod       # prod
```

`--full-refresh` bỏ qua điều kiện incremental `_loaded_at > MAX(...)`, dựng
lại master từ TOÀN BỘ raw. Staging (`type: table`) tự rebuild mỗi lần chạy.

### Cách B — Google Cloud Dataform (không cần CLI)

1. BigQuery → Dataform → chọn repository → workspace
2. Bấm **PULL** (lấy code mới nhất từ GitHub)
3. Tạo **compilation result** mới
4. **START EXECUTION** → chọn:
   - Tags: `wayfair`
   - ✅ tick **Run with full refresh** (quan trọng — để rebuild master từ đầu)
   - Chọn environment (dev/prod)

### Cách C — gcloud (CI/CD)

```bash
gcloud dataform repositories create-compilation-result ... 
gcloud dataform repositories create-workflow-invocation \
  --project=allforwood-dev --location=us \
  --repository=afw-wayfair-sync-dataform \
  --workflow-invocation-config='{"fullyRefreshIncrementalTablesEnabled": true, "includedTags": ["wayfair"]}'
```

## Thứ tự thực thi (Dataform tự sắp theo ref)

```
raw_wayfair_orders
  → stg_wayfair_order (cha) ─┐
  → stg_wayfair_order_line (con) ─┤
       → master_wayfair_order (cha) ─┐
       → master_wayfair_order_line (con) ─┤
            → fact_order_line (join cha-con)
            → fact_sku_pnl_daily (join cha-con)
raw_wayfair_inventory_* → stg → master → mart_wayfair_inventory_daily
```

## Về "state"

- **State Dataform** (incremental): là `MAX(_loaded_at)` trong bảng master.
  `--full-refresh` reset cái này — dùng khi rebuild-from-raw.
- **State watermark C#** (`state_wayfair_watermark`): điều khiển C# fetch API.
  KHÔNG liên quan rebuild-from-raw. Chỉ reset (scripts/reset_sync_state.sql)
  khi muốn C# gọi API lấy lại từ đầu.

## Cách D — REST API (chi tiết, cho automation)

```bash
PROJECT=allforwood-dev
LOCATION=us
REPO=afw-wayfair-sync-dataform

# 1. Tạo compilation result
COMPILE=$(gcloud dataform repositories create-compilation-result "$REPO" \
  --project="$PROJECT" --location="$LOCATION" \
  --git-commitish=main --format="value(name)")

# 2. Tạo workflow invocation với full-refresh + tag wayfair
curl -X POST \
  "https://dataform.googleapis.com/v1/projects/$PROJECT/locations/$LOCATION/repositories/$REPO/workflowInvocations" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "compilationResult": "'"$COMPILE"'",
    "invocationConfig": {
      "includedTags": ["wayfair"],
      "transitiveDependenciesIncluded": true,
      "fullyRefreshIncrementalTablesEnabled": true
    }
  }'
```

Key `fullyRefreshIncrementalTablesEnabled: true` = tương đương "Run with full refresh".
