# Tenant build configuration

Each tenant build needs a `--dart-define-from-file` so `PROJECT_CODE` is set at compile time.

| File | Tenant | Project code |
|------|--------|--------------|
| `dev.json` / `pagariya_prod.json` | Pagariya Mart | RET5677 |
| `myneedmart_dev.json` / `myneedmart_prod.json` | My Need Mart | RET6978 |
| `grahakpeth_dev.json` / `grahakpeth_prod.json` | Grahak Peth | RET9575 |
| `sansarpariwar_dev.json` / `sansarpariwar_prod.json` | Sansar Pariwar | RET6602 |

`*_dev.json` → dev API (`dev-universal-backendapi.shalviadvision.com`).

`*_prod.json` → production API. Before App Store / TestFlight release:

1. Confirm `API_BASE_URL` with your backend team.
2. Set `RAZORPAY_KEY_ID` to the tenant live key, or leave empty if the admin panel supplies it at runtime.

## Build examples

```bash
# My Need Mart — Android APK
./tool/build_tenant.sh myneedmart apk 4.0.14

# My Need Mart — iOS TestFlight IPA
./tool/build_tenant.sh myneedmart ipa 4.0.14

# Pagariya — Play Store bundle
./tool/build_tenant.sh pagariya appbundle 4.0.14
```
