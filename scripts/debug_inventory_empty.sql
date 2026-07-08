-- =============================================================
-- debug_inventory_empty.sql — Vì sao inventory staging rỗng
-- ⚠️ Đổi <PROJECT> = allforwood-dev hoặc allforwood.
-- =============================================================

-- ── LỖI ĐÃ TÌM RA: JSON_VALUE trên OBJECT luôn trả NULL ──
-- Câu filter cũ: WHERE JSON_VALUE(raw_payload,'$.inventoryPosition.castleGate') IS NOT NULL
-- castleGate là OBJECT → JSON_VALUE luôn trả NULL → loại MỌI dòng.
-- Chứng minh:
SELECT
  JSON_VALUE(raw_payload, '$.inventoryPosition.castleGate')  AS jv_object,   -- luôn NULL (sai)
  JSON_QUERY(raw_payload, '$.inventoryPosition.castleGate')  AS jq_object,   -- ra object hoặc 'null' (đúng)
  JSON_VALUE(raw_payload, '$.inventoryPosition.castleGate.onHandQty') AS jv_scalar -- ra số nếu có
FROM `<PROJECT>.afw_wayfair_raw.raw_wayfair_inventory_castlegate`
LIMIT 5;

-- ── Bao nhiêu SKU thật sự CÓ tồn CastleGate? ──
SELECT
  COUNTIF(JSON_QUERY(raw_payload,'$.inventoryPosition.castleGate') IS NOT NULL
          AND JSON_QUERY(raw_payload,'$.inventoryPosition.castleGate') != JSON 'null') AS co_castlegate,
  COUNTIF(JSON_QUERY(raw_payload,'$.inventoryPosition.castleGate') IS NULL
          OR JSON_QUERY(raw_payload,'$.inventoryPosition.castleGate') = JSON 'null')   AS khong_co,
  COUNT(*) AS tong
FROM `<PROJECT>.afw_wayfair_raw.raw_wayfair_inventory_castlegate`;
-- Nếu co_castlegate = 0 → feed hiện chỉ có SKU chưa có tồn (thật sự rỗng tồn).
-- Nếu co_castlegate > 0 → bản staging MỚI (1 dòng/SKU, giữ mọi SKU) sẽ có data.
