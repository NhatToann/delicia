#!/usr/bin/env bash
# setup-branches.sh — Tạo 12 branches (1/use-case) cho team
# Chạy 1 LẦN sau khi git init + initial commit
set -e

BRANCHES=(
  "feat/uc-01-auth"
  "feat/uc-02-client-home"
  "feat/uc-03-realtime-map"
  "feat/uc-04-cart-checkout"
  "feat/uc-05-client-orders"
  "feat/uc-06-client-profile"
  "feat/uc-07-admin-home"
  "feat/uc-08-admin-crud"
  "feat/uc-09-admin-orders"
  "feat/uc-10-delivery-list"
  "feat/uc-11-delivery-details"
  "feat/uc-12-polish-deploy"
)

echo "Creating 12 branches from main..."
for b in "${BRANCHES[@]}"; do
  git branch "$b" main
  echo "  ✓ $b"
done

echo ""
echo "Done! Team có thể làm việc độc lập:"
echo ""
echo "  # Leader (D)"
echo "  git checkout feat/uc-01-auth      # hoặc feat/uc-02-client-home"
echo ""
echo "  # Member A"
echo "  git checkout feat/uc-04-cart-checkout"
echo "  git checkout feat/uc-05-client-orders"
echo "  git checkout feat/uc-06-client-profile"
echo ""
echo "  # Member B"
echo "  git checkout feat/uc-07-admin-home"
echo "  git checkout feat/uc-08-admin-crud"
echo "  git checkout feat/uc-09-admin-orders"
echo ""
echo "  # Member C"
echo "  git checkout feat/uc-03-realtime-map"
echo "  git checkout feat/uc-10-delivery-list"
echo "  git checkout feat/uc-11-delivery-details"
echo "  git checkout feat/uc-12-polish-deploy"
echo ""
echo "Mỗi member khi xong việc:"
echo "  git push origin <branch-name>"
echo "  -> mở Pull Request vào main"
