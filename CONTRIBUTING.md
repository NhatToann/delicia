# 🤝 Contributing — Quy ước làm việc nhóm

## Workflow

```
main  ─────────────────────────────────────────►
  ↑                                                  ↑
  │                                                  │
  └─ feat/uc-01-auth  (Leader)                      │
  └─ feat/uc-04-cart  (Member A) ── PR ──────────────┘
  └─ feat/uc-07-admin (Member B) ── PR ──────────────┘
  └─ feat/uc-03-map   (Member C) ── PR ──────────────┘
```

1. Mỗi member **checkout branch riêng** (xem `scripts/setup-branches.sh`).
2. Code trên branch đó, **không push thẳng vào main**.
3. Khi xong → push + mở **Pull Request** về `main`.
4. **Không cần review approval** (team nhỏ) nhưng phải pass CI:
   - `flutter analyze` 0 errors
   - `flutter test` 100% pass
   - Build APK debug OK

## Branch naming

```
feat/uc-<NN>-<short-name>
fix/<short-desc>
docs/<short-desc>
```

## Commit message (Conventional Commits)

```
feat(uc-04): add CartBloc + CartScreen
fix(uc-01): handle region mismatch for asia-southeast1
docs(readme): add team + branches table
refactor(auth): extract error mapper to AuthFailure enum
test(uc-04): add 3 tests for cart total + add/remove
```

## Trước khi push

```bash
flutter pub get
flutter analyze          # 0 errors
flutter test             # all pass
flutter build apk --debug   # OK
```

## Khi nào cần gộp (merge) thành 1 PR

Nếu bạn đang làm use-case **MỚI** (chưa ai merge) → 1 branch = 1 PR là chuẩn.

Nếu bạn **sửa conflict** do người khác đã merge → rebase branch của bạn về main:

```bash
git checkout feat/uc-04-cart-checkout
git fetch origin
git rebase origin/main
# fix conflicts nếu có
git push --force-with-lease
```

## KHÔNG push lên GitHub

- `google-services.json`, `GoogleService-Info.plist` (đã bị `.gitignore` chặn)
- `*.jks`, `*.keystore` (chứa signing key)
- `tasks/` (docs nội bộ — AI log, use-case spec, chỉ dành cho dev local)
- `build/`, `.dart_tool/`, `.gradle/`
- `serviceAccountKey.json` (Firebase Admin SDK)

## Xem thêm

- `README.md` — quick start + architecture
- `tasks/use-case-XX-*.md` — spec chi tiết (chỉ ở local)
- `tasks/ai-usage.log` — log các phiên dùng AI (chỉ ở local)
