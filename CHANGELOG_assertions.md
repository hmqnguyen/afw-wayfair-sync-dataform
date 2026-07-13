# CHANGELOG — Thêm Assertions (cải tiến theo pattern Amazon)

Ngày: 13/07/2026. Mục tiêu: đưa data-quality của Dataform Wayfair lên ngang Amazon
(`AfwDataform`) bằng cách bake các kiểm tra vào Dataform assertions — chạy tự động mỗi lần build,
thay vì chạy `validate_dedup_keys.sql` thủ công.

**Compile:** `dataform compile` PASS — **41 action** (trước: 14), 0 lỗi.

---

## 1. Inline assertions (`assertions: { uniqueKey, nonNull }`) — 12 model

Mirror pattern Amazon: mỗi model khai báo key nghiệp vụ → Dataform tự sinh assertion
uniqueKey + nonNull, FAIL build nếu vi phạm.

| Model | uniqueKey | nonNull |
|-------|-----------|---------|
| stg_wayfair_order | po_number | po_number, order_date |
| stg_wayfair_order_line | po_number, line_index | po_number, line_index |
| stg_wayfair_inventory_castlegate | supplier_part_number, snapshot_date | (2 cột key) |
| stg_wayfair_inventory_dropship | supplier_part_number, snapshot_date | (2 cột key) |
| stg_wayfair_inventory_castlegate_warehouse | supplier_part_number, warehouse_id, snapshot_date | (3 cột key) |
| master_wayfair_order | po_number | po_number, order_date |
| master_wayfair_order_line | po_number, line_index | po_number, line_index |
| master_wayfair_inventory_castlegate | supplier_part_number, snapshot_date | (2 cột key) |
| master_wayfair_inventory_dropship | supplier_part_number, snapshot_date | (2 cột key) |
| master_wayfair_inventory_castlegate_warehouse | supplier_part_number, warehouse_id, snapshot_date | (3 cột key) |
| fact_order_line | line_uid | line_uid, order_date |
| fact_sku_pnl_daily | brand, channel, region, order_channel_type, sku, day | day |

> Ghi chú: `fact_sku_pnl_daily` chỉ đặt nonNull = `day` (partition key) để tránh false-positive
> khi `sku` có thể null ở một số line — giống cách Amazon giữ nonNull tối thiểu.

## 2. Assertion độc lập — 3 file mới (`definitions/assertions/`)

Copy nguyên tắc từ Amazon, áp cho bảng snapshot theo ngày của Wayfair (inventory).
**KHÔNG áp cho orders** — dữ liệu theo sự kiện (poDate), ngày không có PO là bình thường.

- **`assert_data_freshness.sqlx`** (schema = staging) — neo vào `CURRENT_DATE()` (KHÔNG phải MAX của
  bảng) để bắt ca "job sync ĐÃ CHẾT". Ngưỡng 2 ngày cho 3 bảng inventory (castlegate, dropship,
  warehouse). Đây là ca mà `assert_no_date_gaps` mù (đúng bài học sự cố Amazon 12/07).
- **`assert_no_date_gaps.sqlx`** (schema = staging) — phát hiện lỗ hổng ngày ở GIỮA chuỗi snapshot
  inventory (job nuốt lỗi 1 ngày). Dùng `GENERATE_DATE_ARRAY(min, max)` LEFT JOIN ngày thực có.
- **`assert_no_date_gaps_master.sqlx`** (schema = master) — cùng logic nhưng ở tầng master (nơi
  mart/fact thật sự đọc), bắt ca MERGE incremental làm hụt ngày mà staging vẫn đủ.

## 3. Cách chạy

```bash
dataform compile                 # kiểm cú pháp + graph (đã PASS: 41 actions)
dataform run --tags assertion    # chạy riêng toàn bộ assertion
# hoặc chạy full pipeline: assertion tự chạy sau model tương ứng
```

Assertion trả về CÁC DÒNG VI PHẠM → rỗng = pass; có dòng = FAIL, pipeline dừng.

## 3b. 🔴 BUG assertion PHÁT HIỆN (13/07) — order_date NULL 100%

Khi chạy pipeline, 4 assertion FAIL: `stg_wayfair_order`, `master_wayfair_order`,
`fact_order_line`, `fact_sku_pnl_daily` (rowConditions nonNull).

**Nguyên nhân gốc:** `includes/wayfair.js` — hàm `ts()` KHÔNG parse được format poDate của Wayfair
`2026-03-29 21:04:03.000000 +00:00` (microseconds + offset ' +00:00' có dấu cách & dấu hai chấm).
`SAFE_CAST AS TIMESTAMP` trả NULL với format này; nhánh fallback cũ thiếu `%Ez`. ⇒ `po_timestamp`
và `order_date` NULL cho **755/755 dòng** → `fact_sku_pnl_daily` dồn hết vào partition NULL (P&L
theo ngày hỏng âm thầm).

**Sửa:** thêm nhánh `SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S %Ez', …)` đứng ĐẦU trong `ts()`.
Đã verify parse đúng trên data thật + `dataform compile` PASS (41 actions).

**Cần làm sau khi pull fix:** full-refresh lại staging → master → fact → mart để `order_date` được
điền đúng (rows cũ đang NULL sẽ không tự cập nhật ở master incremental).

> Ghi chú giá trị: đây chính là lý do thêm assertion — một bug tiềm ẩn nghiêm trọng (toàn bộ P&L
> theo ngày sai) bị phát hiện ngay lần chạy đầu thay vì âm thầm cho ra số sai.

## 3c. assert_data_freshness FAIL ở dev — TRUE POSITIVE (không phải bug code)

Inventory dev đứng ở `2026-07-08` (5 ngày, ngưỡng 2). Đúng như thiết kế: assertion báo dữ liệu cũ.
Ở dev thường không chạy sync hằng ngày nên đỏ là bình thường; sẽ xanh ở prod khi sync chạy đều.
Nếu muốn dev khỏi đỏ: chỉ enforce freshness ở prod, hoặc chấp nhận đỏ ở dev.

## 4. Việc còn lại (chưa làm ở bước này)

- Item 2: build master/fact/mart trong dev rồi chạy `dataform run` để các assertion master/fact
  thực sự có bảng để kiểm (hiện dev mới có raw + staging → assertion staging chạy được ngay;
  master/fact assertion cần build lớp đó trước).
- Item 3: settlement/fees + `mart_sku_pnl_daily` (theo `master_amazon_settlement_fees`).
- Item 4: rà soát naming/convention (phần lớn đã khớp: workflow_settings vars, includes/ts()).
