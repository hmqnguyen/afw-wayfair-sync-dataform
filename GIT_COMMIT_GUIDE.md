# Git — Commit AfwWayfairDataform lên repo

Repo: `https://github.com/hmqnguyen/afw-wayfair-sync-dataform.git`

## Lần đầu (repo GitHub còn trống)

```bash
cd AfwWayfairDataform

git init
git branch -M main
git add -A
git commit -m "feat: Wayfair Dataform pipeline (raw → staging → master → fact → mart)

- 4 lớp nghiệp vụ theo quy ước Lecangs (5 dataset, master tách riêng, thêm mart)
- staging: parse + dedupe, expose _loaded_at (orders + 3 inventory)
- master: incremental theo _loaded_at, giữ lịch sử
- fact: order_line + sku_pnl_daily (cross-channel, region US/CA, B2B/B2C)
- mart: inventory_daily (CastleGate + Dropship), sku_pnl_daily (skeleton)
- includes/wayfair.js: ts() helper parse timestamp"

git remote add origin https://github.com/hmqnguyen/afw-wayfair-sync-dataform.git
git push -u origin main
```

## Nếu repo đã có sẵn code (clone rồi copy vào)

```bash
git clone https://github.com/hmqnguyen/afw-wayfair-sync-dataform.git
# copy nội dung AfwWayfairDataform/* vào thư mục clone (trừ .git)
cd afw-wayfair-sync-dataform
git add -A
git commit -m "feat: cập nhật Wayfair Dataform pipeline theo data thật + quy ước Lecangs"
git push
```

## Các lần cập nhật sau

```bash
cd AfwWayfairDataform
git add -A
git commit -m "fix: <mô tả thay đổi>"
git push
```

## Kết nối Dataform (Google Cloud) với repo này

Sau khi push, kết nối repo với Dataform trên GCP:
1. BigQuery → Dataform → Create repository (hoặc dùng repo có sẵn)
2. Settings → Connect with a third-party Git repository
3. Remote URL: `https://github.com/hmqnguyen/afw-wayfair-sync-dataform.git`
4. Default branch: `main`
5. Tạo Personal Access Token trên GitHub (scope `repo`), lưu vào Secret Manager, trỏ Dataform tới secret đó
6. Dataform → Create development workspace → PULL → COMPILE

⚠️ Sau mỗi lần push, vào Dataform bấm **PULL** rồi tạo **compilation result mới** — nếu không sẽ dùng cache cũ.

## Lưu ý
- `.gitignore` đã loại `node_modules/`, `.df-credentials.json`, `.DS_Store`
- `.gitattributes` ép LF cho SQLX/JS/JSON — tránh CRLF từ Windows làm Dataform lỗi parse
- KHÔNG commit `.df-credentials.json` (chứa credential kết nối BigQuery)
