// Helper dùng chung cho Wayfair SQLX.
// Wayfair poDate: '2026-04-27 15:45:03.000000 +00:00' — có microseconds + offset ' +00:00'
// (dấu cách trước offset, dấu hai chấm trong offset).
//
// ⚠️ BUG ĐÃ SỬA (2026-07-13): SAFE_CAST AS TIMESTAMP KHÔNG parse được format này
// (offset kèm dấu cách + microseconds) → trả NULL. Nhánh fallback cũ '%Y-%m-%d %H:%M:%E*S'
// KHÔNG có %Ez nên cũng NULL. Hậu quả: po_timestamp & order_date NULL cho 100% dòng →
// fact_sku_pnl dồn hết vào partition NULL. Assertion nonNull đã phát hiện.
//
// Nhánh %Ez khớp offset RFC3339 '+00:00' (có dấu hai chấm) và phải đứng TRƯỚC để thắng.
function ts(expr) {
  return `COALESCE(` +
    `SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S %Ez', ${expr}), ` +  // Wayfair poDate có offset ' +00:00'
    `SAFE_CAST(${expr} AS TIMESTAMP), ` +
    `SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', ${expr}))`;         // fallback không offset
}
module.exports = { ts };
