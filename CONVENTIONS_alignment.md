# Đối chiếu convention: Wayfair Dataform ↔ Amazon (AfwDataform)

Ngày 13/07/2026. Kết luận: **cấu trúc đã khớp Amazon ~90%**. Sau khi thêm assertions (item 1) và
P&L mart (item 3), phần còn lại chỉ là chỉnh nhỏ cho nhất quán. Bảng dưới liệt kê từng điểm.

## Đã khớp ✅

| Quy ước | Amazon | Wayfair | |
|---|---|---|---|
| Tách dataset 5 lớp (`vars.*_dataset`) | raw/staging/master/fact/mart | y hệt | ✅ |
| Dev/prod tách theo project, KHÔNG `_dev` suffix | allforwood-dev / allforwood | y hệt | ✅ |
| `defaultAssertionDataset` = fact dataset | afw_amazon_fact | afw_wayfair_fact | ✅ |
| Layer separation raw→staging→master→fact→mart | có | có | ✅ |
| includes helper `ts()` parse timestamp | includes/amazon.js | includes/wayfair.js | ✅ |
| Inline `assertions {uniqueKey, nonNull}` mọi model | có | **đã thêm (item 1)** | ✅ |
| `assert_data_freshness` (neo CURRENT_DATE) | có | **đã thêm** | ✅ |
| `assert_no_date_gaps` staging + master | có | **đã thêm** | ✅ |
| P&L: fact grain SKU + mart channel-monthly | có | **đã thêm mart_wayfair_channel_pnl_monthly** | ✅ |
| `name:` trên mart | có | **đã thêm** cho cả 2 mart | ✅ |

## Khác biệt CÓ CHỦ ĐÍCH (không sửa) ⚠️

| Điểm | Amazon | Wayfair | Lý do giữ khác |
|---|---|---|---|
| Kiểu staging | `type: incremental` + dedup MERGE | `type: table` (full-rebuild) | Handoff §4: Wayfair chốt staging full-rebuild, con trỏ incremental đặt ở master. Cả hai đều hợp lệ theo CONVENTIONS mục 4. |
| Nguồn phí P&L | có `master_amazon_settlement_fees` (settlement thật) | chưa có SettlementSync → phí NULL | Wayfair Supplier API chưa expose phí sàn; cần thêm C# SettlementSync. |
| `updatePartitionFilter` ở fact | Amazon dùng cửa sổ 35 ngày | Wayfair CỐ Ý bỏ | Handoff fix F4: đơn cũ bị hủy muộn → cửa sổ ngắn làm MERGE bỏ sót. Đây là cải tiến Wayfair, giữ nguyên. |

## Chỉnh nhỏ tùy chọn (chưa làm — giá trị thấp)

- Tag chi tiết: Amazon dùng tag 3 phần (vd `["mart","amazon","channel_pnl"]`); Wayfair phần lớn 2 phần
  (`["mart","wayfair"]`). Đã áp 3 phần cho model mới; các model cũ có thể thêm dần, không gấp.
- Custom assertion nghiệp vụ (như `assert_settlement_fees_no_unmapped` của Amazon) — chỉ áp được khi
  Wayfair có settlement. Để dành cho item 3 giai đoạn 2.

## Kết luận

Không có lệch cấu trúc nào cần sửa gấp. Các khác biệt còn lại đều là **quyết định thiết kế có lý do**
(staging full-rebuild, bỏ updatePartitionFilter) hoặc **phụ thuộc dữ liệu chưa có** (settlement/COGS),
không phải sai convention.
