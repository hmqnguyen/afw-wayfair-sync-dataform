// Helper dùng chung cho Wayfair SQLX.
// Wayfair poDate: '2026-04-27 15:45:03.000000 +00:00' (có offset).
// ts(expr) → SAFE_CAST AS TIMESTAMP, fallback parse format không offset.
function ts(expr) {
  return `COALESCE(` +
    `SAFE_CAST(${expr} AS TIMESTAMP), ` +
    `SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', ${expr}))`;
}
module.exports = { ts };
