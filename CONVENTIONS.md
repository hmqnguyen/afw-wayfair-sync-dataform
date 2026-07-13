# CONVENTIONS — Nguyên tắc thiết kế pipeline (AFW Data)

Bộ quy tắc chung cho MỌI pipeline mới (Wayfair, Amazon, Walmart, Lecangs…). Rút ra từ
quá trình xây dựng & sửa lỗi pipeline Wayfair. Đọc trước khi thêm bảng/nguồn mới.

---

## 1. Staging trung lập với trạng thái

Staging chỉ **làm phẳng + ép kiểu + dedup kỹ thuật**. Mọi thứ *có thể thay đổi* (hủy, hoàn,
fill, sample, giữ hàng…) chỉ được **ghi thành cột**, KHÔNG bao giờ dùng làm bộ lọc loại dòng.

- Quy tắc kinh doanh (loại đơn hủy, loại hàng mẫu, chọn kênh) áp ở **fact/mart**.
- Lý do: staging là "sự thật thô đã chuẩn hoá"; lọc ở đây làm mất khả năng tái hiện và
  buộc mỗi report tự dựng lại dữ liệu gốc.
- Ví dụ đúng: `is_cancelled` là cột ở staging; `fact_sku_pnl_daily` mới loại nó khỏi doanh thu.

## 2. Cửa sổ ingest/refresh phải phủ trọn vòng đời thay đổi của thực thể

Nếu bảng tổng hợp lọc/phân vùng theo **ngày sự kiện** (vd `order_date`) nhưng trạng thái có
thể đổi sau đó, thì phải:

- (a) chạy incremental theo **ngày cập nhật cuối** (`_loaded_at` / `_src_loaded_at`), KHÔNG
  theo ngày sự kiện; **và**
- (b) không giới hạn `updatePartitionFilter` theo cửa sổ ngắn của ngày sự kiện (nếu không MERGE
  sẽ không ghi được vào partition cũ) — hoặc nới cửa sổ đủ dài để phủ hết vòng đời.

> Ví dụ lỗi đã sửa: đơn đặt cách đây 40 ngày mà hôm nay mới bị hủy. Nếu fact lọc
> `order_date >= CURRENT_DATE − 35d` thì cập nhật hủy kẹt ở master, không tới fact →
> doanh thu vẫn tính đơn đã hủy. Đã đổi cả hai bảng fact sang lái theo `_loaded_at`.

**Bảng tổng hợp (aggregate)** cần pattern "tính lại ngày bị ảnh hưởng":
1. Tìm các ngày có line vừa đổi (theo `_loaded_at > MAX(_src_loaded_at)`).
2. **Tính lại trọn** các ngày đó từ master (không cộng dồn delta).
3. Loại trạng thái (vd hủy) bằng điều kiện **trong SUM**, không lọc ở WHERE — để bucket bị
   hủy sạch vẫn xuất dòng = 0, MERGE ghi đè giá trị cũ về 0.

## 3. Dedup key = định danh vật lý thật của dòng

Không dùng thuộc tính nghiệp vụ **có thể lặp/đổi** làm key.

- Order line: `(po_number, line_index)` — KHÔNG `(po_number, part_number)` (1 PO có thể có 2 line
  trùng part_number).
- Inventory: `supplier_part_number` — KHÔNG `sku` (1 sku có nhiều biến thể).
- Mọi field "thường thì duy nhất" đều phải **kiểm bằng data thật** trước khi tin
  (xem `validate_dedup_keys.sql`).

## 4. Tách vai trò lớp rõ ràng, không trộn

| Lớp | Vai trò | Cơ chế |
|-----|---------|--------|
| **Raw** | Sự thật thô, append-only | KHÔNG dedup; giữ `_ingested_at`, `_source_run_id`, `_source_file` |
| **Staging** | Làm phẳng + "bản mới nhất thắng" | `type: table`; `ROW_NUMBER() … ORDER BY _ingested_at DESC`, giữ `rn = 1` |
| **Master** | Giữ lịch sử + con trỏ incremental | `type: incremental`; `WHERE _loaded_at > MAX(_loaded_at)` |
| **Fact / Mart** | Quy tắc kinh doanh + tổng hợp | Loại/tính theo nghiệp vụ; incremental theo ngày cập nhật |

State incremental của Dataform nằm **ngay trong dữ liệu bảng** (`MAX(_loaded_at)`), không cần bảng state riêng.

## 5. Giữ raw nguyên văn; hiểu đúng ngữ nghĩa kiểu của engine

- Lưu payload đúng casing gốc của API (**camelCase**), kiểu cột **JSON** — không đi qua object
  typed (tránh biến thành PascalCase, tránh mất field mới).
- Trước khi lọc/parse JSON, phải biết luật của engine. Với **BigQuery**:
  - KHÔNG so sánh JSON bằng `=`/`!=` → dùng `JSON_TYPE(JSON_QUERY(x,'$.path')) = 'object'`.
  - `JSON_VALUE` trên object luôn trả NULL → chỉ dùng cho **scalar**; object dùng `JSON_QUERY`.
- Mọi bộ lọc/parse phải kiểm bằng **data thật**, không suy diễn.

## 6. Khai báo phụ thuộc tường minh

- Khai báo source bằng file **declaration `.sqlx`** (một file/nguồn), KHÔNG dựa vào `declare()`
  ngầm trong `.js` → giúp `ref()` resolve ổn định, tránh lỗi "depends on … which does not exist".
- Mỗi model tham chiếu nguồn/model khác qua `ref()`, không hardcode tên bảng.

---

### Checklist khi thêm pipeline/bảng mới

- [ ] Raw append-only, đủ 3 cột meta (`_ingested_at`, `_source_run_id`, `_source_file`) + `raw_payload` JSON.
- [ ] Staging không có bộ lọc trạng thái nghiệp vụ; dedup theo định danh vật lý; xuất `_loaded_at`.
- [ ] Xác minh key bằng SQL (total = distinct_key).
- [ ] Master incremental theo `_loaded_at`; uniqueKey khớp grain.
- [ ] Fact/mart: incremental theo ngày cập nhật; aggregate dùng pattern "tính lại ngày bị ảnh hưởng".
- [ ] Đã kiểm parse/lọc JSON trên data thật.
- [ ] Source khai báo bằng declaration `.sqlx`.
