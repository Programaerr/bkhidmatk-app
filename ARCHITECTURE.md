# ARCHITECTURE.md — Jaik (جايك)

> **Read this before changing code.** It is the orientation map for humans and
> AI agents working on this repository. If you change the structure, update this
> file too.

Jaik is an **Arabic-first, RTL Flutter app for booking home-service craftsmen in
Iraq**. A customer requests a service, the administrator approves the request,
assigns a craftsman, agrees on a price, and issues a printable A5 receipt. The
app also has a short-video "Our Work" feed, customer/admin messaging,
notifications, hiring, and craftsman applications.

The UI language is **Arabic only** (the welcome screen has a small English
toggle, but the rest of the app stays Arabic). Code comments are mostly Arabic.
Keep user-visible strings in Arabic and keep the layout RTL.

### Quick facts (read this if context is tight)

- Flutter app, package `jaik`, entry `lib/main.dart` -> `lib/app.dart`.
- One Provider model: `AppState`; all data access via `state.repo`.
- `Repository` has two implementations: `LocalRepository` (SQLite) and
  `SupabaseRepository` (cloud). Keep them in parity.
- Roles: `customer`, `worker`, `admin`; shells are in `lib/ui/{customer,worker,admin}`.
- Booking lives in `bookings`; statuses: `pending`, `confirmed`, `dispatched`,
  `in_progress`, `completed`, `cancelled`. Price is 0 until the admin sets it.
- UI is Arabic/RTL, Cairo font, gold `#FFD400` + ink `#0B0B0D`.
- Cloud schema/RPCs: `supabase/setup.sql` then `booking_requests.sql`,
  `booking_edits.sql`, `booking_prices.sql`, `home_sections.sql`.
- No `test/` directory; verify with `flutter analyze`.
- Never ship the `service_role` key; only the publishable/anon key is used.

**Suggested reading order for a small model:** sections 1, 2, 5, 6.1, 9, 10.
The long art/UI files can be skipped unless the task is visual.

---

## 1. Tech stack

| Area | Choice |
|---|---|
| Framework | Flutter 3.47.8, Dart `>=3.4.0 <4.0.0` |
| UI | Material 3, Cairo font, RTL, custom glass/3D artwork |
| State | `provider` with one `AppState` (`ChangeNotifier`) |
| Backend | Supabase: Postgres + Auth + Storage + Realtime |
| Offline/local | SQLite via `sqflite` (`sqflite_common_ffi_web` on web) |
| PDF / print | `pdf` + `printing`, A5 receipt |
| Media | `image_picker`, `video_player`, `youtube_explode_dart`, `screenshot` |
| Other | `shared_preferences`, `crypto`, `url_launcher`, `qr_flutter` |

Platform folders exist for Android (primary), iOS, web, Windows, Linux, and
macOS. Android is the main target: `applicationId = com.jaik.app`, minSdk 23,
compile/target SDK 36.

---

## 2. Boot and app wiring

```
lib/main.dart
  -> WidgetsFlutterBinding
  -> web: databaseFactory = databaseFactoryFfiWeb
  -> SupabaseServices.initializeIfConfigured()
       configured?  yes -> SupabaseServices
                    no  -> null (web shows SupabaseSetupApp)
  -> AppState(cloudServices: ...) and state.boot()
  -> ChangeNotifierProvider<AppState>.value
  -> JaikApp
```

`lib/app.dart` (`JaikApp`) builds `MaterialApp` with:

- fixed `locale: ar`, `Directionality.rtl`
- `AppTheme.light()` / `AppTheme.dark()` and `ThemeCrossFade`
- clamped text scaling (0.9–1.3)
- `_RootGate` deciding the first screen:
  - `booting` -> `SplashScreen`
  - `user == null` -> `WelcomeScreen`
  - `isAdmin` -> `CustomerShell` plus a button that opens `AdminShell`
  - `isWorker` -> `WorkerShell`
  - otherwise -> `CustomerShell`

`AppState` (`lib/state/app_state.dart`) owns the session, theme, and language
flag. **It is the only Provider model.** Data access always goes through
`state.repo` (the `Repository` interface), not through screens directly.

### Repository selection

`AppState` constructor:

```dart
repo = repository ??
    (cloudServices == null
        ? LocalRepository()
        : SupabaseRepository(cloudServices.client));
```

- `SupabaseServices` is configured with `--dart-define=SUPABASE_URL=...` and
  `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`. The code also contains fallback
  defaults, so a normal build uses Supabase.
- `LocalRepository` + SQLite is the offline fallback (used when
  `cloudServices == null`, e.g. tests or a deliberately unconfigured build).
- Both implementations must satisfy the same `Repository` interface.

Auth on cloud is **phone + password without SMS/OTP**: the phone is converted to
a synthetic email `<normalized-phone>@jaik.app`, and Supabase Auth handles the
password. There is no real email shown to the user.

---

## 3. Repository map

```
lib/
  main.dart                 entry point, web DB factory, provider
  app.dart                  MaterialApp, RootGate, splash/logo
  core/
    theme.dart              AppColors (gold #FFD400, ink #0B0B0D), themes
    utils.dart              Arabic date/money formatting, phone normalization
  data/
    models.dart             all domain models + status/ack constants
    repository.dart         abstract Repository interface (source of truth)
    repository_local.dart   SQLite implementation
    repository_supabase.dart Supabase implementation
    database.dart           schema v9, migrations, demo seed
    sections.dart           fixed 18 home sections, renamed old sections
    supabase_services.dart  auth, notifications, hire phones, storage helpers
    youtube_stream*.dart    web/io YouTube stream resolver
  state/
    app_state.dart          session, theme, login/register/logout/boot
  ui/
    auth/                   welcome, login, register, craftsman application
    customer/               customer shell + home/services/booking/...
    admin/                  admin shell + dashboard/bookings/services/works/more
    worker/                 worker shell + assigned requests
    common/receipt_document.dart  A5 PDF receipt
    widgets/                shell layout, theme fade, realtime mixin, UI kit
supabase/
  setup.sql                 profiles, auth triggers, RLS, core tables/RPCs
  booking_requests.sql      worker response + dispatch + status RPCs
  booking_edits.sql         admin edit + customer approval
  booking_prices.sql        price agreed later + receipt creation
  home_sections.sql         18 home sections for an existing project
  disable_otp_admin.sql     one-time admin bootstrap helper
tool/                       icon/art generation, Android patching
assets/                     logo, media, Cairo fonts
shaders/liquid_glass.frag   glass effect for the bottom bar
branding/                   source SVGs/PNGs for launcher icons
android/ ios/ web/ ...      platform shells
.github/workflows/build-apk.yml  CI: analyze + build + publish APK
Dockerfile / .devcontainer  reproducible Flutter/Android environment
```

Generated/omitted from edits: `build/`, `.dart_tool/`, `graphify-out/`,
`lib/graphify-out/` (Graphify caches), `.widget_preview/`.

---

## 4. Roles and navigation

Three roles, stored in `AppUser.role` / `app_profiles.role`:

| Role | Shell | Tabs |
|---|---|---|
| `customer` | `CustomerShell` | الرئيسية، الحرفيين، حجوزاتي، أعمالنا، حسابي |
| `worker` (حرفي) | `WorkerShell` | طلباتي، أعمالنا، حسابي |
| `admin` (مدير) | `CustomerShell` + `AdminShell` | dashboard: الرئيسية، الحجوزات، الخدمات، الأعمال، المزيد |

The admin enters the dashboard from the customer account tab
(`onOpenAdminDashboard`). `AdminShell` is pushed on top of the customer shell
with `QuickRoute`, so the phone back button returns to the customer app.

The welcome screen offers:

- `RegisterScreen` — customer registration
- `LoginScreen` — phone + password
- `CraftsmanScreen` — application to become a craftsman
- language toggle / day-night switch / social links

A phone added to **hiring** becomes role `worker` when that person registers.
`admin_users` (cloud) is the authority for admin role; a phone in `admin_phones`
alone does **not** grant admin access.

---

## 5. The booking domain (most important)

### 5.1 Lifecycle

```
customer creates request            status = pending, total = 0
        |
admin reviews
        |-- admin confirms -------> status = confirmed
        |-- admin assigns worker -> worker_response = pending (+ notification)
        |-- admin edits booking --> customer_ack = pending
        |                              customer approves/declines
        |-- admin sets price -----> total = amount + receipt (unpaid)
        |
craftsman accepts/declines          worker_response = accepted | declined
        |
admin dispatches                    status = dispatched
        |                           worker now sees address + customer phone
        v
in_progress -> completed            completed increments worker.jobs_done
        |
customer rates 1..5                 updates worker rating average
```

Cancellation: the customer may cancel only while `pending` or `confirmed`; the
admin may set any status. `dispatched` requires an assigned worker.

### 5.2 Status constants

Defined in `lib/data/models.dart`:

- `BookingStatus`: `pending`, `confirmed`, `dispatched`, `in_progress`,
  `completed`, `cancelled`
- `WorkerResponse`: `pending`, `accepted`, `declined`
- `CustomerAck`: `none`, `pending`, `approved`, `declined`

**Never change these string values** — they are persisted in SQLite, Postgres,
constraints, and RPCs. Add new values with a migration if truly necessary.

### 5.3 Price and receipt

- A service has a catalog price, but the **booking starts at `total = 0`**.
- The admin sets the agreed price with `setBookingPrice`.
- That creates/updates a `receipts` row (`paid = false`) for the customer.
- The admin marks the receipt paid (`markReceiptPaid`); there is **no payment
  gateway** in this app. Payment is manual/demo.
- The customer can preview/print the A5 receipt (`ui/common/receipt_document.dart`).

### 5.4 Worker privacy

Before dispatch, a craftsman must not see the customer's address or phone.
- Cloud: workers read bookings only through the `worker_bookings()` RPC, which
  blanks those fields until status is `dispatched`/`in_progress`/`completed`.
- Local: `LocalRepository.bookingsForWorker` applies `_hideUntilSent`.
- The craftsman row is linked to an account by matching `workers.phone` with
  `app_profiles.phone` (`current_worker_id()`).

---

## 6. Data architecture

### 6.1 The `Repository` interface

`lib/data/repository.dart` is the contract. It covers users, categories, workers,
services, bookings, posts/comments (legacy, see quirks), Our Work videos,
hiring, applications, messages, cards (legacy), receipts, settings, and stats.

**Rule:** every new data operation must be added in three places:

1. `repository.dart` (interface)
2. `repository_local.dart` (SQLite)
3. `repository_supabase.dart` (Supabase)

Keep the two implementations behaviorally identical unless a difference is
unavoidable. Document any intentional difference here.

### 6.2 Local SQLite

`lib/data/database.dart`, file `jaik.db`, **schema version 9**. Tables:

`users`, `categories`, `workers`, `services`, `bookings`, `posts`, `comments`,
`our_works`, `work_comments`, `work_comment_reactions`, `work_likes`, `hires`,
`craftsman_applications`, `messages`, `cards`, `receipts`, `settings`.

Boot creates the schema and seeds demo categories, workers, services, works,
etc. `resetDemoData()` deletes the database file and re-seeds. Local passwords
are `sha256('jaik_v1::' + password)`; this hash is **not** used in the cloud.

Adding a column or table requires:

- bump `_version`
- add an `onUpgrade` branch (`_migrateToV10`, etc.)
- update `_createSchema` for fresh installs
- update the model's `toMap`/`fromMap`

### 6.3 Supabase (cloud)

Tables created by `supabase/setup.sql`:

`app_profiles`, `hire_phones`, `admin_phones`, `admin_users`,
`craftsman_applications`, `app_notifications`, `categories`, `workers`,
`services`, `bookings`, `posts`, `post_likes`, `comments`, `our_works`,
`work_likes`, `work_comments`, `work_comment_reactions`, `messages`, `cards`,
`receipts`, `settings`.

Storage bucket: `jaik-media` (uploads under `folder/<auth-uid>/<timestamp><ext>`).
Only the publishable/anon key is used by the app. **`service_role` must never
be shipped in the app or read from `.env` at runtime.**

Important cloud helpers/RPCs:

- `current_app_profile_id()` — profile id of the logged-in auth user
- `is_app_admin()` — checks `admin_users`
- `current_worker_id()` — links a worker account to a `workers` row by phone
- `update_booking_status`, `assign_booking_worker`, `worker_respond_booking`,
  `worker_bookings`, `admin_update_booking`, `customer_respond_booking_edit`,
  `set_booking_price`, `rate_booking`
- `send_app_notification`, `notify_profile`, `notify_admins`
- triggers: `create_app_profile` on `auth.users`, `prepare_booking`,
  `prepare_receipt`, status/notification triggers, admin/hire promotion triggers
- RLS: customers read their own bookings; admins read/manage everything; workers
  cannot select `bookings` directly, only via `worker_bookings()`

### 6.4 Local vs cloud differences

| Concern | Local | Cloud |
|---|---|---|
| Auth | local users + SHA-256 hash | Supabase Auth, phone→`<phone>@jaik.app` |
| IDs | SQLite `INTEGER` | Postgres `bigint` |
| Booleans | `0`/`1` in rows | real `boolean`; repo converts via `_read`/`_write` |
| Realtime | `changes` stream never emits | subscribes to `messages` + notifications |
| Media | stores local file paths | uploads to `jaik-media` |
| Notifications | none | `app_notifications` + triggers + realtime |
| Booking price | admin sets later | same, enforced by SQL |
| Worker privacy | `_hideUntilSent` | `worker_bookings()` RPC |
| Reset demo | deletes and reseeds `jaik.db` | not available |

### 6.5 SQL run order

For a fresh Supabase project run, in order:

1. `supabase/setup.sql`
2. `supabase/booking_requests.sql`
3. `supabase/booking_edits.sql`
4. `supabase/booking_prices.sql`
5. `supabase/home_sections.sql` (needed on an existing project for the 18 sections)

All are written to be re-runnable. `booking_prices.sql` must run after
`booking_edits.sql` because both redefine `prepare_booking()`.

---

## 7. UI conventions

- **Arabic + RTL everywhere.** User-facing text is Arabic; use `AppColors`,
  `AppTheme`, and the shared widgets instead of raw colors/styles.
- Brand: gold `#FFD400`, ink `#0B0B0D`, paper `#F6F6F0`; Cairo font.
- Money via `fmtMoney` (Iraqi dinar, rounded); dates via helpers in
  `core/utils.dart`.
- `AppShellLayout` (`ui/widgets/shell_layout.dart`) is used by all three shells.
  It keeps at most 3 tabs alive, animates tab entry, uses a glass bottom bar on
  phones and a navigation rail at width >= 900.
- Navigation uses `QuickRoute` for a consistent page transition.
- Screens that need fresh data use the `RealtimeRefresh` mixin
  (`ui/widgets/realtime_refresh.dart`). Pages reload when they become visible;
  `listensLive` opens a live subscription only while visible.
- The login/home experience uses custom-painted art and 3D key buttons:
  `truck_art.dart`, `truck_scene.dart`, `workers_art.dart`, `workers_scene.dart`,
  `thinking_art.dart`, `thinking_scene.dart`, `home_keys.dart`, `work_reel.dart`,
  `push_key.dart`, `raised_field.dart`. These are large design files; change
  them only for visual work and read them in slices.
- Receipt layout/printing lives in `ui/common/receipt_document.dart`.
- Image/video display helpers: `ui/widgets/media_view.dart`.

### Fixed home sections

`lib/data/sections.dart` defines the 18 customer sections in order (سبالت،
كهرباء، سباكة، صباغ، التنظيف، اجهزة المنزل، مجاري، نجار، حداد، ديكورات، تركيب
كامرات، حدائق، طاقة شمسية، عامل، ابواب و شبابيك، نقل الاثاث، شد و تركيب الاثاث،
غسيل سيارات). The same list exists in `supabase/home_sections.sql` and the local
seed/migration. Keep all three in sync. Admin-added sections are appended after
the fixed 18.

---

## 8. Where to change what

| Task | Files |
|---|---|
| New screen/tab | `ui/<role>/...`, shell file, `NavItem` list |
| New domain operation | `repository.dart` + both repositories + migration/SQL |
| Booking rules | `repository_local.dart`, `repository_supabase.dart`, `supabase/booking_*.sql` |
| Auth/registration | `supabase_services.dart`, `state/app_state.dart`, `ui/auth/` |
| Theme/colors | `core/theme.dart` |
| Arabic formatting | `core/utils.dart` |
| Receipt layout | `ui/common/receipt_document.dart` |
| Home sections | `data/sections.dart`, `supabase/home_sections.sql`, local seed |
| Alerts/notifications | `supabase_services.dart`, triggers in `supabase/*.sql` |
| Android build/branding | `android/`, `branding/`, `tool/patch_android.py` |
| CI/APK release | `.github/workflows/build-apk.yml` |

---

## 9. Build, run, verify

```bash
flutter pub get
flutter run                    # needs .dart-defines.json / --dart-define
flutter analyze                # must stay clean; CI uses --no-fatal-infos --no-fatal-warnings
flutter build apk --release
```

VS Code launch configs (`Flutter: Supabase (كلمة المرور)`) read
`.dart-defines.json`, which is generated from `.env` by
`.vscode/prepare_supabase_defines.ps1`. Both `.env` and `.dart-defines.json`
are gitignored.

CI (`.github/workflows/build-apk.yml`) runs `tool/patch_android.py`,
`flutter pub get`, `flutter analyze`, builds the release APK, and publishes
`jaik-1.0.0.apk` to the `latest` GitHub release.

Docker/Dev Container: `Dockerfile` + `.devcontainer/devcontainer.json`
(Flutter 3.47.8, JDK 17, Android SDK 36, NDK). Open the repo in VS Code and
“Reopen in Container”.

There is currently **no `test/` directory**; verification is `flutter analyze`
plus manual/APK testing. Add tests if you introduce pure logic worth covering.

---

## 10. Rules for AI agents

1. **This is a small-context setup.** `.opencode/opencode.json` runs a local
   model with an 8k context. Read only the files relevant to the task; use
   `grep`/`glob` first. Avoid loading the large art files (`*_art.dart`,
   `*_scene.dart`, `work_reel.dart`, `push_key.dart`, `raised_field.dart`) unless
   the task is visual.
2. **Do not rename persisted strings.** Booking statuses, worker responses,
   customer acks, roles, section names, and setting keys are stored in databases
   and SQL constraints.
3. **Keep local and cloud parity.** A behavior change in one repository must be
   mirrored in the other and, when server-enforced, in `supabase/*.sql`.
4. **Never add a secret.** Only the Supabase publishable/anon key belongs in the
   app. `.env` contains a `service_role` key and must remain ignored.
5. **Preserve Arabic/RTL.** New UI text in Arabic, `TextDirection.rtl` assumed.
   Use `EdgeInsetsDirectional`, `AlignmentDirectional`, and existing widgets.
6. **Migrations are additive.** Bump the SQLite version, add an upgrade branch,
   and update `_createSchema`. Make Supabase SQL idempotent (`if not exists`,
   `create or replace`).
7. **Don’t touch generated output:** `build/`, `.dart_tool/`, `graphify-out/`,
   `lib/graphify-out/`. The Graphify graph is refreshed with
   `graphify update .` (see `.opencode/skills/graphify/SKILL.md`).
8. **Check before finishing:** run `flutter analyze`; report any remaining
   errors/warnings honestly. There is no automated test suite.
9. **Match the surrounding style.** Comments are Arabic or English but code
   naming is English. Keep diffs focused; do not reformat unrelated code.

---

## 11. Known quirks and legacy pieces

- **`posts` / `post_likes` / `comments`** exist in models, repositories, and
  SQL, but there is no current community-posts screen. Treat as legacy unless
  the task explicitly targets them.
- **`cards` / `PaymentCard`** also exist in the data layer but are not exposed
  in the current UI; payments are manual receipts, not card processing.
- The README mentions “Mastercard (demo)”; this is marketing copy. The actual
  flow is: admin sets price → receipt is created → admin marks it paid.
- The “Local preview” VS Code config passes `DEV_ADMIN_PREVIEW=true`, but that
  define is not referenced in `lib/`; the fallback defaults still configure
  Supabase. Do not rely on that config for offline work.
- `assets/images/logo.jpg` is the brand logo; `branding/` holds launcher icon
  sources and `tool/gen_icons.py` regenerates Android mipmaps.
- The bottom bar uses `shaders/liquid_glass.frag`; keep the shader asset
  declared in `pubspec.yaml`.
- `youtube_explode_dart` needs `xml ^7`, hence the `dependency_overrides` in
  `pubspec.yaml`. Keep it unless the dependency is removed.

---

## 12. Glossary

| Arabic | English |
|---|---|
| جايك | Jaik (app name) |
| زبون | customer |
| حرفي / فني | craftsman / technician / worker |
| مدير | administrator |
| حجز | booking |
| خدمة | service |
| قسم | section / category |
| وصل | receipt |
| أعمالنا | Our Work (video feed) |
| توظيف | hiring (phone enrollment) |
| طلب حرفي | craftsman application |
| إشعار | notification |
| محافظة | governorate / city |
| د.ع | Iraqi dinar |
