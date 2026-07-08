#!/usr/bin/env bash
# Khởi tạo git + commit + push AfwWayfairDataform lên GitHub.
# Chạy TRONG thư mục AfwWayfairDataform: ./git_init_push.sh
set -euo pipefail

REPO="https://github.com/hmqnguyen/afw-wayfair-sync-dataform.git"

if [ -d .git ]; then
  echo "==> .git đã tồn tại — commit thay đổi mới."
  git add -A
  git commit -m "${1:-chore: cập nhật Wayfair Dataform}" || echo "Không có thay đổi để commit."
  git push
else
  echo "==> Init repo mới."
  git init
  git branch -M main
  git add -A
  git commit -m "${1:-feat: Wayfair Dataform pipeline (raw → staging → master → fact → mart)}"
  git remote add origin "$REPO"
  git push -u origin main
fi
echo "==> Xong. Nhớ vào Dataform (GCP) bấm PULL + tạo compilation result mới."
