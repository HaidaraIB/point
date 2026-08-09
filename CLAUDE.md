# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Point is a cross-platform Flutter application for digital marketing agencies: it centralizes clients, employees, content plans, and production tasks (design, copy, photo/video, montage, publishing, promotions). Data lives primarily in **Firebase** (Auth, Firestore, Storage, FCM); **Supabase** complements it for Edge Functions (e.g. email without CORS on web), storage URLs, and server-adjacent workflows. The UI is localized (Arabic-oriented workflows and copy throughout). Web targets agency dashboards; mobile separates account-holder / employee flows from a client experience (`ClientHome`).

## Commands

```bash
flutter pub get                              # install deps
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...   # run (Supabase vars required at runtime)
flutter analyze                              # lint (flutter_lints, see analysis_options.yaml)
flutter test                                 # run all tests
flutter test test/theme_controller_test.dart # run a single test file
dart run tool/i18n_audit.dart                # audit translation key parity (run after adding UI strings)
```

Optional dart-defines: `SUPABASE_STORAGE_BASE_URL`, `R2_SIGNER_URL`, `R2_PUBLIC_BASE_URL`, and (debug builds only) `TEST_ADMIN_PASSWORD` for the seeded `admin` test account (`ensureTestAdminUser` in `FireStoreServices`). See `lib/config/app_config.dart` for the full list.

CI: `codemagic.yaml` / `codemagic-ios-config.example.env` for iOS builds; GitHub Actions builds Android → Google Drive on push to `master` (see `docs/GITHUB_ACTIONS_ANDROID_SETUP.md`).

## Architecture

State management, DI, and routing all go through **GetX** (`get` package):
- `lib/Bindings/AppBindings.dart` — dependency injection for controllers.
- `lib/Controller/` — one GetX controller per screen/business flow.
- `lib/Routing/AppRouting.dart` — named `GetPage` routes; `app_route_observer.dart` for navigation observing; auth middleware gates main app sections. Web and mobile have separate splash-decider entry screens (`WebAuthSplashDecider`, `MobileSplashDecider`, `WebClientAuthSplashDecider`, `MobileClientSplashDecider`) that route based on auth/user-type state.
- `lib/main.dart` — entry point: Supabase + Firebase init, notification setup, `runApp`.

Layer layout under `lib/`:
- `Models/` — data models.
- `Services/` — Firestore access (`FireStoreServices.dart`, largest/most central service), FCM, storage, email, audio, helpers; `Services/firestore/`, `Services/meta/`, `Services/notifications/` subpackages; `StorageKeys` constants.
- `Localization/` — `LanguageController` (must be used for locale changes — don't call `Get.updateLocale` directly), `AppTranslations`, `AppLocaleKeys`, `notify_translations_map.dart`.
- `Utils/` — colors and shared utilities.
- `config/` — compile-time config (`AppConfig`) reading `--dart-define` values.
- `View/` — screens grouped by feature: `Auth`, `Home`, `Clients`, `ClientDashboard`, `Contents`, `Employees`, `EmployeeDashboard`, `Tasks` (with `Dialogs/` for design/writing/photography/montage/programming/promotion/publishing flows), `Publish`, `Library`, `Statistics`, `History`, `Attendance`, `AdminSettings`, `Chats`, `Mobile` (mobile-only account/employee/client screens), `Shared` (shared widgets).

Other top-level pieces: platform runners (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`); `supabase/` — Supabase project assets, including `supabase/functions/scheduled-notifications/index.ts` (Edge Function); `workers/r2-presign` — Cloudflare Worker for R2 presigned uploads; `functions/` — Firebase Cloud Functions (Node); `assets/` — images, SVGs, sounds.

### Refactoring hotspots

These files are large; prefer incremental splits (extract widgets/helpers/services) in the area you're touching rather than a repo-wide refactor:
- `lib/View/Contents/ContentsTable.dart` (shell) + `contents_table_*_part.dart` (desktop table, mobile, add-content dialog; employee-web variant is `contents_table_employee_web_part.dart`, a `part of` the main file)
- `lib/Services/FireStoreServices.dart`
- `lib/View/Home/Home.dart`, `lib/Controller/HomeController.dart`
- `lib/View/Tasks/Dialogs/*.dart` (several 800–1100+ lines)
- `lib/View/Chats/ChatPage.dart`, `MChatPage.dart`

## Internationalization (must follow — see `docs/i18n_guidelines.md`)

- Every user-facing string must go through a translation key (`.tr`) — no hardcoded strings in `lib/View`.
- Add each new key to both `ar` and `en` under the same name, using scoped prefixes (`common.*`, `auth.*`, `home.*`, `chat.*`, `errors.*`).
- Locale changes go through `LanguageController` only.
- UI must never display a raw `error.toString()`; map errors to `errors.*` keys. Backend services should return stable `errorCode`s rather than raw messages.
- After adding/changing translations, run `dart run tool/i18n_audit.dart` and `flutter test test/i18n_translations_parity_test.dart`.

## Secrets

Never commit real API keys. Firebase config lives in `lib/firebase_options.dart` (FlutterFire-generated); Supabase URL/anon key and other runtime secrets are injected via `--dart-define` (see `lib/config/app_config.dart`), not hardcoded.
