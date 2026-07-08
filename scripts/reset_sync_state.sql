-- =============================================================
-- reset_sync_state.sql — Reset watermark C# để sync lại từ đầu
--
-- CHỈ dùng khi muốn C# OrdersSync bỏ qua watermark và fetch lại toàn bộ
-- window từ Wayfair API (KHÁC với rebuild-from-raw — cái đó không gọi API).
--
-- Lưu ý: inventory là snapshot nên không có watermark; chỉ orders (nếu về
-- sau chuyển sang incremental-by-watermark) mới dùng bảng này.
--
-- ⚠️ Đổi <PROJECT> thành allforwood-dev hoặc allforwood.
-- =============================================================

-- Xóa toàn bộ watermark → lần sync sau bắt đầu lại từ lookback mặc định
DELETE FROM `<PROJECT>.afw_wayfair_state.state_wayfair_watermark` WHERE TRUE;

-- Hoặc reset watermark 1 domain cụ thể về mốc xa trong quá khứ:
-- MERGE `<PROJECT>.afw_wayfair_state.state_wayfair_watermark` T
-- USING (SELECT 'orders' AS domain) S ON T.domain = S.domain
-- WHEN MATCHED THEN UPDATE SET last_synced_utc = TIMESTAMP('2026-01-01 00:00:00+00'), updated_at_utc = CURRENT_TIMESTAMP();
