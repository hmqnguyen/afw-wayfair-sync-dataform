-- =============================================================
-- drop_legacy_tables.sql — Dọn bảng CŨ mồ côi sau khi tách cha-con
--
-- Cấu trúc orders đã đổi:
--   stg_wayfair_orders     → stg_wayfair_order + stg_wayfair_order_line
--   master_wayfair_orders  → master_wayfair_order + master_wayfair_order_line
-- Bảng tên cũ KHÔNG còn được Dataform ghi → xóa để tránh nhầm lẫn.
--
-- ⚠️ Đổi <PROJECT> thành allforwood-dev hoặc allforwood trước khi chạy.
-- Chạy: bq query --use_legacy_sql=false --location=US < drop_legacy_tables.sql
-- =============================================================

DROP TABLE IF EXISTS `<PROJECT>.afw_wayfair_staging.stg_wayfair_orders`;
DROP TABLE IF EXISTS `<PROJECT>.afw_wayfair_master.master_wayfair_orders`;

-- (tùy chọn) Nếu trước đây fact_sku_pnl_daily từng có grain cũ (thiếu region/
-- order_channel_type) và anh muốn rebuild sạch thay vì MERGE chồng, xóa luôn:
-- DROP TABLE IF EXISTS `<PROJECT>.afw_wayfair_fact.fact_sku_pnl_daily`;
-- DROP TABLE IF EXISTS `<PROJECT>.afw_wayfair_fact.fact_order_line`;
