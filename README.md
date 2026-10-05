# M18 Residences — admin app

The admin page of M18 Residences (https://admin.m18-residences.workers.dev): rooms, tenants, electricity readings,
bills and payment receipts. Flutter web, hosted as a static-assets Cloudflare Worker (`admin`).

## Receipts

Receipts can be JPEG, PNG, WebP, GIF, AVIF, HEIC/HEIF or PDF. Before uploading, the app converts images in the
browser (`lib/features/billing/receipt_converter.dart`): at most 1600 px on the long edge, WebP at quality 0.8
(JPEG if the browser can't write WebP), keeping the original when that is smaller. HEIC is decoded by the vendored
[heic-to](web/vendor/heic-to/README.md) (LGPL-3.0), loaded only when a HEIC file is picked. PDFs are uploaded as-is.

## Getting started

1. **API URL:** copy `.env.example` to `.env` (repo root). `API_URL` (including `/api`) is compiled in with
   `--dart-define-from-file=.env`; without it the app stops at startup with a clear error. Locally the API runs
   on `http://localhost:50000/api` (see `m18-residences-server`), which only allows this app on port 50001.
2. **Shared package:** models, the API client and common widgets come from `m18_residences_shared`
   ([shared-packages](https://github.com/whatever413y/shared-packages), pinned by tag in `pubspec.yaml`). To work
   against a local checkout next to this repo, add a gitignored `pubspec_overrides.yaml`:

   ```yaml
   dependency_overrides:
     m18_residences_shared:
       path: ../shared-packages/packages/m18_residences_shared
   ```

3. **Run or build:**

   ```sh
   flutter pub get
   flutter run -d chrome --web-port 50001 --dart-define-from-file=.env
   flutter build web --release --dart-define-from-file=.env
   ```

   To serve a build the way production does: `npx wrangler@4.145.0 dev --port 50001`.

Code layout is feature-first: `lib/features/<feature>/{bloc,widgets}/`.

## Checks and deploys

- `flutter analyze` must report no issues; `dart format lib` (150 columns).
- `test.yml`: PRs to `main` → format, analyze, release build.
- `preview.yml`: the same checks, then a **preview** on this app's Worker, built against the development API
  (`development-api`, synthetic data) and behind Cloudflare Access (log in with an allowed email); production is
  untouched:
  - pushes to `development` → https://development-admin.m18-residences.workers.dev
  - pull requests from this repo → `https://pr-<number>-admin.m18-residences.workers.dev`, linked in a PR comment
- `deploy.yml`: pushes to `main` → the same checks → the browser e2e suite (`shared-e2e`) with this commit and
  the server and tenant app as they are live → build with the repo variable `API_URL` → `wrangler deploy` → moves
  the `live` tag.

Browser e2e builds use `--dart-define=E2E=true`, which keeps Flutter's accessibility tree on; tests find widgets by
semantics ids (e.g. `admin-username`, `room-save`, `bill-total-<tenant>`, `bill-attach-receipt`).
