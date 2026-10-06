# M18 Residences — admin app

The admin page of M18 Residences (https://admin.m18-residences.workers.dev): rooms, tenants, electricity readings,
bills with the tenant's payment image and the owner's receipt, and the payment QR codes tenants pay with. Flutter web, hosted as a static-assets Cloudflare Worker (`admin`). The production site
is behind Cloudflare Access: log in with an allowed email (one-time code), then with the admin login.

## Screens

After login, `lib/features/shell/admin_shell.dart` shows the pages: **Dashboard**, **Verify**, **Billing**,
**Electric Readings**, **Tenants**, **Rooms** and **Payment QR Codes**, as an extended side rail on desktops, a
rail on tablets and a bottom bar on phones (Home, Verify, Billing, Readings; the rest and Logout under **More**).
Opening a page reloads its data; pages stay built, so filters are kept. Light and dark follow the system
(`AppTheme.light` / `AppTheme.dark` from `m18_residences_shared`).

- **Dashboard** (`lib/features/dashboard/`): for the latest bill month, billed, collected (bills with a receipt),
  outstanding and occupancy (rooms with an active tenant); the bills that need attention (payments to verify, then
  unpaid); billed vs collected over 12 months. All computed in the app from the bills list (no extra request).
- **Verify** (`lib/features/verify/`): bills with a tenant's payment and no receipt; View payment, then **Attach
  receipt** (the same upload as the Update Bill form) marks the bill Paid. The rail shows how many are waiting.
- **Search** (every page's app bar): tenants and rooms; picking one opens Billing with all of their bills.

**Logo and icons:** the roofline M (teal mark on dark slate, so the admin tab stands apart from the tenant app). `web/icons/logo.svg` and `logo-maskable.svg` are the masters; `web/favicon.svg` is a copy, and the PNGs (`favicon.png`, `icons/Icon-*.png`, `icons/apple-touch-icon.png`) are rendered from them at their sizes in Chrome. In the app, `BrandMark` from `m18_residences_shared` draws the same mark.

## Receipts and payments

A bill has two optional files: the **payment** image from the tenant (they upload it in the tenant app; the admin
can attach or change it too) and the **receipt** from the owner. The table's Status column and the bill
details show **Unpaid**, **For verification** (payment, no receipt) or **Paid** (receipt). Both open with View
buttons in a preview dialog; no file names or links are shown.

Files can be JPEG, PNG, WebP, GIF, AVIF, HEIC/HEIF or PDF. Before uploading, they are converted in the browser by
`prepareReceipt` from `m18_residences_shared`: at most 1600 px on the long edge, WebP at quality 0.8 (JPEG if the
browser can't write WebP; a WebP already smaller than its re-encoding is kept); HEIC is decoded by the package's
heic-to asset (LGPL-3.0), loaded only when needed; PDFs are uploaded as-is. A receipt or payment can be attached
when generating the bill or later (`lib/features/billing/widgets/attach_file_button.dart`), and removed with
Remove in the Update Bill form (applied on save; Billing Details only shows the status and View buttons); replacing or removing one
moves the old file to the archive (`archive/` in R2, kept forever). Files are picked with the shared `pickFile` (a plain file input that works on iPhone/iPad Safari).

## Payment QR codes

"Payment QR Codes" shows the BPI, GCash and Maya QR images tenants see. Replace converts the
picked image (HEIC included) to a PNG of at most 1024 px in the browser and uploads it.

## Lists

Bills and readings are a sortable table on tablets and desktops and sortable cards on phones
(`lib/utils/responsive_table.dart`); their filters start at the current month. Picking a tenant sets the room only
when generating a bill or adding a reading. Clicking a row or card opens its details; the lists' own text isn't selectable (a
click always opens the details), while the details and other dialogs (`showSelectableDialog`) can be selected and copied.

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
  (`development-api`, synthetic data; open, no Access); production is untouched:
  - pushes to `development` → https://development-admin.m18-residences.workers.dev
  - pull requests from this repo → `https://pr-<number>-admin.m18-residences.workers.dev`, linked in a PR comment
- `deploy.yml`: pushes to `main` → the same checks → the browser e2e suite (`shared-e2e`) with this commit and
  the server and tenant app as they are live → build with the repo variable `API_URL` → `wrangler deploy` → moves
  the `live` tag.

Browser e2e builds use `--dart-define=E2E=true`, which keeps Flutter's accessibility tree on; tests find widgets by
semantics ids (e.g. `admin-username`, `room-save`, `bill-total-<tenant>`, `bill-attach-receipt`).
