# AfwWayfairDataform — Transform Repo

Transform raw Wayfair (do AfwWayfairSync C# ghi) → staging → master → fact → mart.
Quy ước đặt tên & layer theo **AfwLecangsDataform**.

## Kiến trúc 4 lớp + mart

```
afw_wayfair_raw (C# ghi)
   └─→ afw_wayfair_staging   (parse JSON + dedupe, expose _loaded_at)
          └─→ afw_wayfair_master   (incremental theo _loaded_at, giữ lịch sử)
                 └─→ afw_wayfair_fact    (order line, SKU P&L cross-channel)
                        └─→ afw_wayfair_mart  (inventory daily, P&L skeleton)
```

**5 dataset** (raw/staging/master/fact/mart) — master TÁCH RIÊNG khỏi fact.
Dev/prod **CÙNG tên dataset** (không _dev), tách theo project.

## Cấu trúc

```
definitions/
  sources/sources.js                                  ← declare 3 raw tables
  staging/
    stg_wayfair_orders.sqlx                           ← UNNEST products[] + region + order_channel_type
    stg_wayfair_inventory_castlegate.sqlx             ← SKU-level (castleGate + physicalRetail)
    stg_wayfair_inventory_castlegate_warehouse.sqlx   ← UNNEST warehouses[] (theo kho con)
    stg_wayfair_inventory_dropship.sqlx               ← kho NM5
  master/
    master_wayfair_orders.sqlx
    master_wayfair_inventory_castlegate.sqlx
    master_wayfair_inventory_castlegate_warehouse.sqlx
    master_wayfair_inventory_dropship.sqlx
  fact/
    fact_order_line.sqlx                              ← line_uid hash, grain po×part
    fact_sku_pnl_daily.sqlx                           ← cross-channel, fee NULL
  mart/
    mart_wayfair_inventory_daily.sqlx                 ← hợp nhất CastleGate + Dropship
    mart_sku_pnl_daily.sqlx                           ← SKELETON (disabled)
includes/wayfair.js                                   ← ts() helper parse timestamp
```

## Pattern mỗi lớp

**Staging** (`type: table`): parsed CTE (JSON_VALUE) → ranked CTE (ROW_NUMBER dedupe) → SELECT expose `_loaded_at`.

**Master** (`type: incremental`, uniqueKey): `WHERE _loaded_at > (SELECT MAX(_loaded_at) FROM ${self()})`. Giữ lịch sử.

**Fact** (`type: incremental`): đọc từ master, partition + updatePartitionFilter 35 ngày.

**Mart** (`type: table`): tổng hợp BI.

## Xử lý đặc thù từ data thật
- `region`: tách 'US'/'CA' từ salesChannelName ('Wayfair' vs 'Wayfair Canada')
- `order_channel_type`: 'B2B'/'B2C' (null orderType → B2C)
- `warehouses[]`: UNNEST thành bảng warehouse-level (supply chain cần cho quyết định CastleGate 90-day free storage)
- `fact_sku_pnl_daily` dùng chung cross-channel: uniqueKey gồm channel, Amazon/Wayfair không đè nhau

## Dataset mapping (dev = prod)

| Layer | Dataset |
|---|---|
| Raw | afw_wayfair_raw |
| Staging | afw_wayfair_staging |
| Master | afw_wayfair_master |
| Fact | afw_wayfair_fact |
| Mart | afw_wayfair_mart |

## Chờ nguồn ngoài
- Wayfair Settlement API → platform_fee/fulfillment_fee/storage_fee
- afw_sku_cogs (Airtable→BQ) → bật mart_sku_pnl_daily
