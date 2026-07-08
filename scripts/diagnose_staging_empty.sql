-- =============================================================
-- diagnose_staging_empty.sql — Tìm chỗ mất dữ liệu khi staging trống
--
-- Chạy TỪNG câu (theo thứ tự), xem kết quả để khoanh vùng.
-- ⚠️ Đổi <PROJECT> = allforwood-dev (hoặc allforwood) — đúng project anh chạy job.
-- Chạy: bq query --use_legacy_sql=false --location=US '<từng câu>'
-- =============================================================

-- ────────────────────────────────────────────────────────────
-- BƯỚC 1: RAW có dữ liệu không? (staging đọc từ đây)
-- Nếu = 0 → C# sync CHƯA chạy / chạy vào project khác. Staging trống là đúng.
-- ────────────────────────────────────────────────────────────
SELECT COUNT(*) AS raw_row_count
FROM `<PROJECT>.afw_wayfair_raw.raw_wayfair_orders`;

-- ────────────────────────────────────────────────────────────
-- BƯỚC 2: raw_payload có phải kiểu JSON thật không?
-- Xem cột data_type: PHẢI là 'JSON'. Nếu là 'STRING' → JSON_VALUE trả NULL hết
-- → staging parse ra toàn NULL, po_number NULL → bị lọc mất → TRỐNG.
-- ────────────────────────────────────────────────────────────
SELECT column_name, data_type
FROM `<PROJECT>.afw_wayfair_raw.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'raw_wayfair_orders';

-- ────────────────────────────────────────────────────────────
-- BƯỚC 3: Giá trị brand thực tế trong raw là gì?
-- Staging lọc WHERE brand = 'AFW'. Nếu brand là 'afw'/NULL/khác → lọc sạch.
-- ────────────────────────────────────────────────────────────
SELECT brand, COUNT(*) AS n
FROM `<PROJECT>.afw_wayfair_raw.raw_wayfair_orders`
GROUP BY brand;

-- ────────────────────────────────────────────────────────────
-- BƯỚC 4: JSON_VALUE có parse được po_number không?
-- Nếu po_number cột ra NULL nhưng raw_payload có data → raw_payload bị
-- double-encode (lưu dạng JSON string thay vì JSON object).
-- ────────────────────────────────────────────────────────────
SELECT
  brand,
  JSON_VALUE(raw_payload, '$.poNumber')      AS po_number,
  JSON_VALUE(raw_payload, '$.salesChannelName') AS channel,
  -- Kiểm tra products[] có unnest được không:
  ARRAY_LENGTH(JSON_QUERY_ARRAY(raw_payload, '$.products')) AS n_products
FROM `<PROJECT>.afw_wayfair_raw.raw_wayfair_orders`
LIMIT 5;

-- ────────────────────────────────────────────────────────────
-- BƯỚC 5: Xem raw_payload thô 1 dòng (kiểm tra cấu trúc thật)
-- Nếu thấy raw_payload bắt đầu bằng dấu " và có \" bên trong → DOUBLE-ENCODE.
-- ────────────────────────────────────────────────────────────
SELECT TO_JSON_STRING(raw_payload) AS payload_preview
FROM `<PROJECT>.afw_wayfair_raw.raw_wayfair_orders`
LIMIT 1;

-- ────────────────────────────────────────────────────────────
-- BƯỚC 6: Bảng staging đã được TẠO chưa? Có phải tên MỚI không?
-- Sau khi tách cha-con, tên đúng là stg_wayfair_order (số ít) +
-- stg_wayfair_order_line. Nếu chỉ thấy stg_wayfair_orders (số nhiều, CŨ)
-- → Dataform chạy code CŨ do CACHE compile → cần tạo compilation result mới.
-- ────────────────────────────────────────────────────────────
SELECT table_name, creation_time
FROM `<PROJECT>.afw_wayfair_staging.INFORMATION_SCHEMA.TABLES`
WHERE table_name LIKE 'stg_wayfair_order%'
ORDER BY creation_time DESC;
