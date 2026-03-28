# Point

Point is a cross-platform Flutter application for **digital marketing agencies**: it centralizes **clients**, **employees**, **content plans**, and **production tasks** (design, copy, photo/video, montage, publishing, promotions, and more). Data lives primarily in **Firebase** (Authentication, Cloud Firestore, Cloud Storage, FCM). **Supabase** complements the stack for **Edge Functions** (e.g. email without CORS on web), storage URLs, and related server-side workflows. The UI is **localized** (Arabic-oriented workflows and copy throughout the app). **Web** targets agency dashboards; **mobile** separates account-holder / employee flows and a **client** experience (`ClientHome`).

## Key Features

*   **Client & employee management**: Maintain client records (regions, interests, campaigns) and staff; role-aware navigation with an **employee dashboard** separate from the main agency home.
*   **Content catalog**: Track marketing deliverables across types (image, video, reel, story, ads, article, text, graphic, podcast, live) and major **social / ad platforms** (Meta, Google Ads, TikTok, etc.).
*   **Task workflows**: End-to-end task lifecycle with statuses (draft, revision, approval, scheduling, publishing, rejection, editing, etc.) and specialized dialogs for **design**, **writing**, **photography**, **montage**, **programming**, **promotion**, and **publishing**.
*   **Home & analytics**: Dashboard widgets and **Syncfusion** charts for content and client insights; **statistics** screen for reporting.
*   **History**: General **history** plus **task history** for auditing and follow-up.
*   **Notifications**: **Firebase Cloud Messaging** and **local notifications** on non-web platforms; optional email flows via Supabase-backed functions.
*   **Rich media**: Video playback, PDF viewing (Syncfusion), file pickers / drop zones, optional sounds (non-web).
*   **Responsive UI**: Shared components and layouts tuned for **mobile** and **desktop/web** (`ResponsiveScaffold`, adaptive home).

## Technology Stack & Architecture

*   **Framework**: Flutter (Dart ^3.7), `flutter_localizations`.
*   **State management & routing**: `get` (GetX) — controllers, bindings, and named routes with auth middleware on main app sections.
*   **Backend**:
    *   **Firebase**: `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`; configuration via `lib/firebase_options.dart` (FlutterFire).
    *   **Supabase**: `supabase_flutter` — client init in `main.dart`; functions invocation from services (e.g. mail, server-adjacent logic).
*   **Charts & documents**: `syncfusion_flutter_charts`, `syncfusion_flutter_pdfviewer`.
*   **UI**: `google_fonts`, `flutter_svg`, `lucide_icons`, `font_awesome_flutter`, `emoji_picker_flutter`, etc.
*   **CI**: `codemagic.yaml` and `codemagic-ios-config.example.env` for iOS/build secrets patterns.

## Project Structure

The codebase is grouped by feature and layer under `lib/`:

```
lib/
├── Bindings/       # GetX dependency injection (auth, home, client controllers)
├── config/         # Compile-time app config (e.g. Supabase dart-define keys)
├── Controller/     # GetX controllers for screens and business flows
├── Localization/   # Language controller, translations, locale keys
├── Models/         # Data models
├── Routing/        # AppRouting, auth middleware, GetPage definitions
├── Services/       # Firestore, FCM, storage, email, audio, helpers, StorageKeys constants
├── Utils/          # Colors, shared utilities
├── View/           # Screens: Auth, Home, Clients, Contents, Employees, Tasks, Statistics, History, Mobile, Chats, Shared widgets, …
└── main.dart       # Entry: Supabase + Firebase init, notifications, runApp
```

Root folders of note: `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` — platform runners; `supabase/` — Supabase project assets; `assets/` — images, SVGs, sounds; `docs/` — internal notes (e.g. i18n); `scripts/`, `tool/` — automation helpers.

## Setup and Installation

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/HaidaraIB/point.git
    cd point
    ```

2.  **Install Flutter dependencies:**
    ```sh
    flutter pub get
    ```

3.  **Configure Firebase**  
    Ensure `lib/firebase_options.dart` matches your Firebase project (e.g. via [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup)). Add platform files as required (`google-services.json`, `GoogleService-Info.plist`, etc.).

4.  **Configure Supabase (required at runtime)**  
    The app reads the public URL and anon key from **compile-time defines** (see `lib/config/app_config.dart`). Pass them when running or building, for example:
    ```sh
    flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
      --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
    ```
    Optionally set `SUPABASE_STORAGE_BASE_URL` if your app expects a dedicated public storage base URL.

5.  **Secrets and CI**  
    Do not commit real API keys. For Codemagic / iOS, see `codemagic-ios-config.example.env` for variable names (e.g. plist content, Supabase keys).

6.  **Debug-only helpers**  
    In debug builds, `TEST_ADMIN_PASSWORD` can be supplied via `--dart-define` for test account flows (see `AppConfig`). Test users are created as **`admin`** (`ensureTestAdminUser` in `FirestoreServices`).

7.  **Run the app:**
    ```sh
    flutter run
    ```
    On **web**, the initial route is the login flow; on **mobile**, the splash decider routes users appropriately.

---

For internationalization conventions used in the project, see `docs/i18n_guidelines.md`.
