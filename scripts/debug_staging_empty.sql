-- =============================================================
-- debug_staging_empty.sql — Tìm lý do bảng staging rỗng
--
-- Chạy TUẦN TỰ từng câu trong BigQuery Console (chọn đúng project).
-- ⚠️ Đổi <PROJECT> = allforwood-dev (hoặc allforwood — CHÍNH project
--    mà anh chạy Dataform, KHÔNG phải project khác).
-- Dừng ở câu nào trả kết quả bất thường → đó là chỗ đứt.
-- =============================================================

-- ── B1. RAW có dữ liệu chưa? (nghi phạm #1: C# chưa ghi / ghi sai project) ──
SELECT COUNT(*) AS raw_rows
FROM `<PROJECT>.afw_wayfair_raw.raw_wayfair_orders`;
-- = 0  → RAW rỗng. C# sync chưa chạy HOẶC ghi vào project khác.
--        Kiểm tra project trong launchSettings/Cloud Run có khớp <PROJECT> không.
-- > 0  → sang B2.


-- ── B2. brand có đúng 'AFW' không? (nghi phạm #2: filter brend loại hết) ──
SELECT brand, COUNT(*) AS n
FROM `<PROJECT>.afw_wayfair_raw.raw_wayfair_orders`
GROUP BY brand;
-- Nếu brand KHÁC 'AFW' (vd null, 'afw', 'AFW ') → WHERE o.brand='AFW' loại sạch.


-- ── B3. raw_payload là JSON THẬT hay STRING double-encode? (nghi phạm #3, HAY GẶP) ──
SELECT
  po_check,
  products_len
FROM (
  SELECT
    JSON_VALUE(raw_payload, '$.poNumber')                 AS po_check,
    ARRAY_LENGTH(JSON_QUERY_ARRAY(raw_payload, '$.products')) AS products_len
  FROM `<PROJECT>.afw_wayfair_raw.raw_wayfair_orders`
  LIMIT 3
);
-- po_check = NULL  → raw_payload bị double-encode (lưu dạng JSON-string thay vì
--   JSON object). Đây là bug hay gặp: C# serialize row thành string TRƯỚC khi
--   gán vào raw_payload. => JSON_VALUE trả NULL toàn bộ => staging rỗng.
-- products_len = NULL/0 → UNNEST products[] ra 0 dòng => stg_wayfair_order_line rỗng
--   (dù stg_wayfair_order cha vẫn có thể có dữ liệu).


-- ── B4. Kiểm tra kiểu cột raw_payload trong schema ──
SELECT column_name, data_type
FROM `<PROJECT>.afw_wayfair_raw`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'raw_wayfair_orders' AND column_name = 'raw_payload';
-- data_type phải là 'JSON'. Nếu là 'STRING' → bảng tạo sai kiểu.


-- ── B5. Xem thẳng 1 raw_payload để mắt thường kiểm tra ──
SELECT brand, TO_JSON_STRING(raw_payload) AS payload_preview
FROM `<PROJECT>.afw_wayfair_raw.raw_wayfair_orders`
LIMIT 1;
-- payload_preview đúng phải là object: {"id":...,"poNumber":"CS...","products":[...]}
-- Nếu thấy dạng "{\"id\":...\"poNumber\"...}" (có dấu \" escape) => double-encode.


-- ── B6. Bảng staging có TỒN TẠI không? (nghi phạm #4: Dataform chưa tạo / cache cũ) ──
SELECT table_name, creation_time
FROM `<PROJECT>.afw_wayfair_staging`.INFORMATION_SCHEMA.TABLES
WHERE table_name LIKE 'stg_wayfair_%'
ORDER BY table_name;
-- Nếu KHÔNG thấy stg_wayfair_order / stg_wayfair_order_line → job chưa chạy
--   đúng file (có thể chạy compilation cache CŨ, hoặc tên bảng cũ stg_wayfair_orders).
-- Nếu THẤY nhưng 0 dòng → nguyên nhân ở B1-B3.


-- ── B7. Nếu staging tồn tại: đếm dòng từng bảng ──
SELECT 'stg_wayfair_order' AS tbl, COUNT(*) n FROM `<PROJECT>.afw_wayfair_staging.stg_wayfair_order`
UNION ALL
SELECT 'stg_wayfair_order_line', COUNT(*) FROM `<PROJECT>.afw_wayfair_staging.stg_wayfair_order_line`;
