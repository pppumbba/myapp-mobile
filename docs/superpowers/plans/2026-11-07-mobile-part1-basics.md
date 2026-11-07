# Phone app part 1: basics. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Flutter Android app, built per app meta, that signs in, shows the app's screens as bottom tabs + More, lists datagrid records as cards with search, filters and buttons, and adds/edits records through native forms with lookups. The Assets app (local meta 160) runs end to end on a real phone against the local backend.

**Architecture:**
- **Layers:**
  - a small API layer (dio)
  - typed models of the meta API
  - pure Dart "logic" files: menu flattening, card slots, query building, form values and payloads, error mapping. These are unit tested and ported from the web React code they name.
  - widgets on top
- **State:** Riverpod providers hold the session (token, user, access, session values) and cache meta definitions, as the web `render/definitions.ts` does.
- **One Android project** reads an ignored `app.json` for the applicationId and name. The app meta id, customer and API base come in through `--dart-define`.

**Tech Stack:**
- Flutter 3.47.9 stable, Dart 3
- flutter_riverpod, go_router, dio, flutter_secure_storage, flutter_localizations + intl (ARB)
- http_mock_adapter (tests)
- JDK 21, Android SDK

**Spec:** `docs/superpowers/specs/2026-11-07-flutter-mobile-design.md`. This plan covers its "Order of work" step 1. The stage-query sheet is included because the spec puts grid buttons (Complete) in the basics.

**Later plans, one per spec step:**
- 2: form scripts
- 3: workspace + tabs
- 4: details
- 5: files
- 6: dashboards/charts/calendar
- 7: phone settings

## Global Constraints

- **Online only:** no local database, no sync.
- **Android only:** the `android/` project. Don't create ios/web/desktop folders: `flutter create --platforms=android`.
- **Built per app:**
  - `--dart-define=APP_META_ID=<int>`, `CUSTOMER_CODE=<code or empty>` and `API_BASE=<url ending in /api>`.
  - `android/app/build.gradle` reads `../../app.json` {appId, appName, color} for `applicationId` and the `app_name` resValue. `app.json` is gitignored.
- **Definitions** are read the way the web reads them:
  - `GET /metas/{id}?translated=1`
  - `GET /metas/{id}/params?effective=1&translated=1` (a tree with `children`)
  - `GET /metas/{id}/actions?effective=1&translated=1`
- **Signed-in requests** carry `Authorization: Bearer <token>`, `Accept: application/json` and `Accept-Language: <user locale>`. They use no `/c/{code}` prefix: the token is bound to the customer. Only guest calls (`/mobile/{id}` before login) use `/c/{CUSTOMER_CODE}` when a code is set.
- **Permissions** follow the web `can()`: an admin can do everything, a null meta id is allowed, otherwise `access.metas["<id>"][ability]` where ability ∈ view/create/edit/delete.
- **Supported kinds in this part:** `datagrid`, `form`. Every other kind is left out of the menu. Where it's reached another way, it shows the "Open on the web" notice.
- **Look:** Material 3 with `ColorScheme.fromSeed(seedColor: app colour)`. The default colour is `#4f46e5`.
- **UI strings** go in `lib/l10n/app_en.arb` and `app_mn.arb`, never hard-coded. The locale is `user.locale` (`en`/`mn`), falling back to the device.
- **Tests:** `flutter test` must pass and `flutter analyze` must report no issues at every commit.

## Review Focus

1. **The token expires or is revoked (401 on any call).** The app clears the token and shows sign-in, without crashing or looping. Test in Task 2 (`apiClient on 401 calls onUnauthorized once`).
2. **A lookup column's value has no display text in the row.** The card or form shows the lookup grid's `display_field` for that value, never a raw id. Test in Task 5 (`cellText for lookup uses <field>_display… else resolver`).
3. **A grid has mandatory criteria (`missing_filters` non-empty).** The list shows "Choose a filter first" naming them and opens the filter sheet, not an empty list. Test in Task 7.
4. **The server returns 422 with keys for fields not on screen**, e.g. `lines.0.qty` or an unknown key. The first message still shows in a banner at the top of the form, and field keys show under their fields. Test in Task 8.
5. **No network or a timeout.** The "The server could not be reached" message shows with a Retry button that reloads. The app doesn't spin forever. Test in Task 2 (`network error maps to ApiError status 0`).

---

### Task 1: Replace the Capacitor shell with a Flutter project and the per-app build

**Files:**
- Delete: `package.json`, `package-lock.json`, `capacitor.config.ts`, `scripts/build.mjs`, `android/` (Capacitor), `www/`, `node_modules/`
- Create: the Flutter project at the repo root (`flutter create --platforms=android --org mn.wand --project-name wand_mobile .`)
- Create: `tool/build_app.dart`, `lib/config.dart`, `test/config_test.dart`
- Modify: `android/app/build.gradle(.kts)`, `.gitignore`, `README.md`

**Interfaces:**
- Produces: `class AppConfig { final int appMetaId; final String? customerCode; final String apiBase; static AppConfig fromEnvironment(); }`. It reads `const int.fromEnvironment('APP_META_ID')`, `String.fromEnvironment('CUSTOMER_CODE')` (empty → null) and `String.fromEnvironment('API_BASE', defaultValue: 'https://5-223-38-162.sslip.io/api')`. The api base is stored without a trailing `/`.
- Produces: `dart run tool/build_app.dart --app <id> [--customer <code>] [--api <url>] [--release]`:
  1. GETs `<api>[/c/<customer>]/mobile/<id>`.
  2. Fails with the server message on non-200 or a missing `package_id`.
  3. Writes `app.json` {appId: package_id, appName: name, color (valid #rrggbb or `#4f46e5`)}.
  4. Runs `flutter build apk [--debug|--release] --dart-define=...`. The customer is `--customer` or the response's `customer.code`.

- [ ] **Step 1: Install the toolchain and check it**
  - Unpack `C:\Users\User\dev\dl\flutter.zip` to `C:\Users\User\dev\flutter` once its sha256 matches `d8e2b5977e09082c6440f89dc1aa887b94c8fbcc3b39222797046295a3f68a9e`.
  - The Android cmdline-tools are in `C:\Users\User\dev\android-sdk\cmdline-tools\latest`.
  - Set user env `ANDROID_HOME=C:\Users\User\dev\android-sdk`, add `flutter\bin` and `android-sdk\platform-tools` to the user PATH, and point `JAVA_HOME` at JDK 21 (`flutter config --jdk-dir`).
  - Run `sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"`, use the versions `flutter doctor` asks for, then `flutter doctor --android-licenses`.
  - Run: `flutter doctor -v`. Expected: Flutter and Android toolchain ✓ (Visual Studio/Chrome ✗ is fine).

- [ ] **Step 2: Remove the Capacitor files, create the Flutter project, and add the dependencies listed in Tech Stack (`flutter pub add …`, dev: `http_mock_adapter`)**

- [ ] **Step 3: Write the failing test `test/config_test.dart`**

```dart
test('apiBase has no trailing slash and empty customer is null', () {
  final c = AppConfig(appMetaId: 160, customerCode: '', apiBase: 'http://x/api/');
  expect(c.apiBase, 'http://x/api');
  expect(c.customerCode, isNull);
});
```

- [ ] **Step 4: Run `flutter test test/config_test.dart`.** Expected: FAIL (AppConfig not defined).

- [ ] **Step 5: Implement `AppConfig` (its constructor normalises both fields) and `tool/build_app.dart`.** In `build.gradle`, read `app.json` with `groovy.json.JsonSlurper` (or `kotlinx`/`JsonSlurper` in .kts) and fall back to `[appId: 'mn.wand.mobile', appName: 'Wand']`. Keep `namespace = "mn.wand.wand_mobile"` fixed. `.gitignore` adds `app.json`.

- [ ] **Step 6: Run `flutter test`, then `dart run tool/build_app.dart --app 160 --api http://<PC LAN IP>/api` with Herd serving that host.** Expected: `app.json` has `mn.wand.eam_app`/`Assets`, and `build/app/outputs/flutter-apk/app-debug.apk` exists. If Herd only serves `myapp-backend.test`, use `adb reverse tcp:8000 tcp:8000` + `php artisan serve --host=0.0.0.0` and `--api http://127.0.0.1:8000/api`. Note in the README whichever works.

- [ ] **Step 7: Commit** `feat: Flutter project and per-app build replace the Capacitor shell`

---

### Task 2: API client and models

**Files:**
- Create: `lib/api/client.dart`, `lib/api/models.dart`, `test/api/client_test.dart`, `test/api/models_test.dart`

**Interfaces:**
- Produces:
  - `class ApiError implements Exception { final int status; final String message; final Map<String, List<String>> errors; }`
  - `class ApiClient { ApiClient(AppConfig config, {Dio? dio}); String? token; String? locale; void Function()? onUnauthorized; Future<T> get<T>(String path, {Map<String, dynamic>? query, bool guest = false}); Future<T> post<T>(String path, Object? body); Future<T> put<T>(String path, Object? body); Future<void> delete(String path); }`
    - Paths are relative to apiBase, e.g. `/metas/160`.
    - `guest: true` prefixes `/c/<customerCode>` when set.
    - Query maps encode nested maps as `k[name]=v` and skip null/'' (port of `dataApi.ts queryString`).
  - Models with `fromJson`:
    - `Meta {id, code, name, type (String?), jsonConfig (Map), refMetaId, tableName, scripts (Map<String,String?> of the five *_expression_string columns)}`
    - `MetaParam {id, parentId, refMetaId, orderNumber, fieldPath, paramName, labelName, dataType, renderType, iconCls, isShow, isRequired, isCriteria, isLabel, isPrimary, widgetPosition, displayField, valueField, filterAs (Map?), defaultValue, jsonConfig (Map), children (List<MetaParam>)}`
      - `String get label => labelName ?? paramName;`
    - `MetaAction {id, gridMetaId, action, label, iconCls, formMetaId, getMetaId, needsRow, showInToolbar, showInRow, orderNumber, params (Map<String,String>)}`
    - `DataPage {rows (List<Map<String,dynamic>>), currentPage, lastPage, total, footer (Map), missingFilters (List<String>)}`
    - `Access {isAdmin, metas (Map<String, Map<String,bool>>)}`
    - `bool can(int? metaId, String ability)`

- [ ] **Step 1: Write the failing tests**

```dart
test('query encodes nested maps and skips empties', () { // via a public encodeQuery()
  expect(encodeQuery({'filter': {'status': 'idle', 'x': ''}, 'search': 'pump', 'page': 2}),
      {'filter[status]': 'idle', 'search': 'pump', 'page': '2'});
});
test('422 maps message and field errors', () async { /* adapter replies 422 {message:'The title field is required.', errors:{title:['The title field is required.']}} */
  expect(err.status, 422); expect(err.errors['title']!.first, 'The title field is required.');
});
test('apiClient on 401 calls onUnauthorized once', () async { /* two parallel 401s → callback count 1 */ });
test('network error maps to ApiError status 0', () async { /* adapter throws DioException.connectionError */ });
test('guest get adds /c/acme', () async { /* request path == /c/acme/mobile/160 */ });
test('params tree parses children and label falls back to param_name', () { /* fixture */ });
test('Access.can: admin true, null id true, missing meta false', () { ... });
```

- [ ] **Step 2: Run `flutter test test/api`.** Expected: FAIL.
- [ ] **Step 3: Implement the client and models.** The error message for status 0 is the l10n string `serverUnreachable`; the client takes it as a constructor arg so it stays testable. A 401 calls `onUnauthorized` once per token, by remembering the token it fired for.
- [ ] **Step 4: Run `flutter test test/api`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: API client and meta models`

---

### Task 3: Session (sign-in, customer, access, session values) and the start screens

**Files:**
- Create: `lib/auth/session.dart`, `lib/auth/sign_in_page.dart`, `lib/app.dart`, `lib/main.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_mn.arb`, `l10n.yaml`, `test/auth/session_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Access`, `AppConfig`.
- Produces:
  - `class SessionState {MobileInfo? info; Map<String,dynamic>? user; Access? access; Map<String,dynamic> sessionValues; bool loading; String? error;}`
  - `class MobileInfo {id, name, color, customerCode}`
  - `final sessionProvider = NotifierProvider<SessionController, SessionState>`
  - `SessionController` methods:
    - `Future<void> start()`: guest GET `/mobile/{id}`, then restores the token from secure storage and calls `loadUser()`.
    - `Future<void> signIn(String email, String password)`: POST `/login`.
      - If the response `token` is bound (one customer), use it.
      - Otherwise pick the customer whose `code == info.customerCode` from `customers` and POST `/customers/{id}/use`, taking its `token`.
      - If none matches, set `error` to the l10n `noAccessToCustomer`.
    - `Future<void> loadUser()`: GET `/user`, `/user/access`, `/user/session` in parallel.
    - `Future<void> signOut()`: POST `/logout`, then clear storage.
    - `bool can(int? metaId, String ability)`
    - `String? sessionValue(String path)`
- The router (in `lib/app.dart`): `/splash`, `/sign-in`, then the shell (Task 4). Redirects follow session state. `onUnauthorized` → `signOut()` without the POST.

- [ ] **Step 1: Write failing tests with a mocked ApiClient:**
  - `signIn uses bound token when one customer`
  - `signIn switches to CUSTOMER_CODE customer when several` (expects POST `/customers/7/use` and the stored token == the `use` response token)
  - `signIn errors when user is not in the customer`
  - `start restores token and loads user/access/session`
  - `401 during loadUser returns to signed-out state`
- [ ] **Step 2: Run `flutter test test/auth`.** Expected: FAIL.
- [ ] **Step 3: Implement the session, the sign-in page and the splash.**
  - The sign-in page has the app name, the app colour, email and password fields, and a button that shows a spinner and the error text.
  - The theme is seeded from `info.color`.
  - The locale is `user['locale']`. Set `client.locale` too.
- [ ] **Step 4: Run `flutter test`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: sign-in, customer and session`

---

### Task 4: App menu → bottom tabs + More, and the screen switch

**Files:**
- Create: `lib/nav/menu.dart`, `lib/nav/shell.dart`, `lib/meta/defs.dart`, `lib/screens/screen_view.dart`, `lib/screens/open_on_web.dart`, `test/nav/menu_test.dart`, `test/meta/defs_test.dart`

**Interfaces:**
- Produces:
  - `class MetaDef {Meta meta; List<MetaParam> params;}`
  - `final metaDefProvider = FutureProvider.family<MetaDef, int>`: cached until sign-out or a manual refresh, like `definitions.ts loadDef`.
  - `final actionsProvider = FutureProvider.family<List<MetaAction>, int>`
  - `final metaTypeProvider = FutureProvider.family<String?, int>`: the type of a ref meta, read via `metaDefProvider`.
  - `class MenuEntry {MetaParam item; String? group;}`
  - `class MobileMenu {List<MenuEntry> tabs; List<MenuEntry> more;}`
  - `MobileMenu flattenMenu(List<MetaParam> appParams, {required bool Function(int metaId) canView, required bool Function(int metaId) supported, int maxTabs = 4})`:
    - Walks `is_show` items in order_number order.
    - An item with `refMetaId` that is viewable and supported is a screen. Its `group` is the label of the nearest ancestor without a ref.
    - With ≤ maxTabs screens, all are tabs. Otherwise the first maxTabs−1 are tabs and the rest go in `more`.
  - `Widget ScreenView({required int metaId, Map<String,String> fixed = const {}, Map<String,String> filters = const {}})` switches on the meta type: `datagrid` → GridScreen (Task 7), `form` → FormScreen (Task 8), else `OpenOnWeb(meta)`.
- The shell:
  - A Material 3 `NavigationBar` with one destination per tab plus "More".
  - The More page is a list with group headers.
  - Each tab keeps its own navigator stack (`StatefulShellRoute.indexedStack`).
  - The top bar has the title and an account sheet (name, customer, sign out).
  - Menu icons come from `icon_cls`, mapped to Material icons through a map in `nav/icons.dart`, with a generic fallback that is **not** a circle: `Icons.widgets_outlined`.

- [ ] **Step 1: Write failing tests**
  - In `menu_test.dart`, use the Assets app tree from the spec (Overview dashboard; Assets group: register/workspace/transfers; …) as a fixture, with supported = datagrid/form only.
    - Expect the tabs to be [Asset register, Transfers, Work orders] + More, with the More list starting with PM plans (group "Maintenance").
    - Expect a hidden item (`is_show` false) and a non-viewable item to be missing.
    - Expect an app with 3 screens to have 3 tabs and no More.
  - In `defs_test.dart`: `metaDefProvider fetches meta and params once for two reads`.
- [ ] **Step 2: Run `flutter test test/nav test/meta`.** Expected: FAIL.
- [ ] **Step 3: Implement.** `supported` checks the ref meta's type, so the shell loads the types of all menu refs with `metaTypeProvider` before building the menu, and shows a skeleton meanwhile.
- [ ] **Step 4: Run `flutter test`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: app menu as bottom tabs and More`

---

### Task 5: Cell text and card slots

**Files:**
- Create: `lib/grid/cells.dart`, `lib/grid/card_slots.dart`, `lib/grid/record_card.dart`, `test/grid/cells_test.dart`, `test/grid/card_slots_test.dart`, `test/grid/record_card_test.dart`

**Interfaces:**
- Produces:
  - `String cellText(MetaParam p, Map<String,dynamic> row, {String? Function(MetaParam p, Object? value)? lookupText})`, ported from the web `render/Cell.tsx` / `formValues.ts` formatting:
    - money: grouping with 2 decimals
    - decimal: as sent
    - date: `yyyy-MM-dd`
    - datetime: `yyyy-MM-dd HH:mm`
    - boolean: the l10n Yes/No
    - lookup: the row's `<field>_display` or `<display_field>` key if present, else `lookupText`
    - files: a "📎 n" count
    - null: ''
    - Before writing it, read `Cell.tsx` and match the key the backend uses for lookup display text.
  - `class CardSlots {MetaParam? title; MetaParam? subtitle; MetaParam? badge; MetaParam? image; List<MetaParam> body; List<MetaParam> footer;}`
  - `CardSlots cardSlots(List<MetaParam> gridParams)`:
    - Only `is_show` params that aren't widgets. A slot taken by `widget_position` wins.
    - Then title = the first `isLabel`, else the first shown param.
    - subtitle = the next shown param.
    - badge = the first `renderType == 'status'`.
    - body = up to 3 more.
    - (Phone settings join this order in plan 7.)
  - `Color statusColor(String value, List<String> options)`: a stable colour per option index from the scheme's tonal palette.
  - The `RecordCard` widget takes `{CardSlots slots, Map row, VoidCallback? onTap, VoidCallback? onMore}`. It renders the title (1 line, ellipsis), subtitle, badge chip, body as "Label: value" rows (each 1 line, ellipsis) and footer, plus a ⋯ button when `onMore` != null. Long-press calls `onMore`.

- [ ] **Step 1: Write failing tests:**
  - `cellText money groups thousands and 2 decimals` (1234567.5 → `1,234,567.50`)
  - `cellText for lookup uses <field>_display… else resolver`
  - `cardSlots picks is_label title, status badge, 3 body fields` (asset register params from the spec: title Asset, subtitle Tag, badge Status, body Category/Location/Department)
  - `cardSlots honours widget_position`
  - `RecordCard with 40-char values does not overflow at 360 px width` (a widget test with `tester.binding.setSurfaceSize(Size(360, 800))`, and expect no exceptions)
- [ ] **Step 2: Run `flutter test test/grid`.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `flutter test test/grid`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: card slots and cell text`

---

### Task 6: Lookups

**Files:**
- Create: `lib/form/lookup.dart`, `lib/form/lookup_page.dart`, `test/form/lookup_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `metaDefProvider`, `CardSlots`/`RecordCard`.
- Produces:
  - `class LookupSpec {int gridMetaId; String valueField; String displayField;}`
  - `LookupSpec? lookupSpecOf(MetaParam p)`: from `refMetaId`, `valueField ?? 'id'` and `displayField ?? the grid's label param`. With `filter_as` it uses those keys instead.
  - `Future<String?> lookupText(LookupSpec s, Object? value)`: GET `/metas/{grid}/data?filter[<valueField>]=<value>&per_page=1`, cached per (grid, value) until a write.
  - `Future<Map<String,dynamic>?> pickLookup(BuildContext, LookupSpec s, {Map<String,String> filters})`: a full-screen page with a search box and an infinite list of RecordCards from that grid. Tapping one returns its row.

- [ ] **Step 1: Write failing tests:**
  - `lookupSpecOf uses value_field/display_field and defaults`
  - `lookupText caches per value` (one request for two calls)
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Before choosing the filter key, check how the web `LookupField.tsx` resolves the display of a saved value, and match it.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: lookups`

---

### Task 7: Grid screen: list, search, filters, buttons, stage-query sheet

**Files:**
- Create: `lib/grid/grid_query.dart`, `lib/grid/grid_screen.dart`, `lib/grid/filter_sheet.dart`, `lib/grid/row_actions.dart`, `lib/stage_query/stage_query_sheet.dart`, `test/grid/grid_query_test.dart`, `test/grid/row_actions_test.dart`, `test/grid/grid_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 4, 5, 6, and `FormScreen.open` from Task 8 (`Future<bool> openForm(BuildContext, {required int formMetaId, Object? recordId, Map<String,String> fixed, Map<String,String> defaults})`, which returns true when saved).
- Produces:
  - `class GridQuery {String search; Map<String,String> filter; Map<String,String> scope; int page; int perPage = 20; String? sort; String dir;}`
  - `Map<String,dynamic> toQuery()`
  - `List<MetaAction> rowActions(List<MetaAction> all, {required bool Function(int?, String) can, required int gridMetaId})`: `showInRow` actions, ordered, filtered by permission. Edit needs `edit`, delete needs `delete`, the rest need `view` on their form/target.
  - `MetaAction? addAction(...)`: the `add` action if the user can `create`.
  - `Map<String,String> actionParams(MetaAction a, Map<String,dynamic> row)`: maps `params {target: source}` from the row. A `=text` source gives fixed text, as in the web `drilldown.ts`.
  - `Future<void> runStageQuery(BuildContext, {required int stageQueryMetaId, required Map<String,String> params})`: a bottom sheet ported from `render/StageQueryView.tsx`/`StageQueryDialog`:
    - one input per stage-query param, prefilled from `params`
    - "Check" calls `POST /metas/{id}/run` with the dry-run flag the web sends, and shows the affected-rows text
    - "Run" calls it for real, then shows the result message
    - On success the grid refreshes.
    - Read `StageQueryView.tsx` for the exact body keys.
- `GridScreen(metaId, {fixed, filters})` behaviour:
  - Search field (debounced 300 ms) → `search`.
  - Filter button with a count badge → `FilterSheet`, which lists the `isCriteria` params using the field widgets from Task 8 (lookups via `filter_as`) and has Apply/Clear. Option and lookup filters show counts from GET `/metas/{id}/facets?fields[]=…` (with the current search/filter/scope), as the web `GridSidebar.tsx` does.
  - Active filters show as removable chips.
  - Infinite scroll by page. Pull to refresh.
  - FAB Add when `addAction` != null.
  - Tap a card:
    - the drilldown from `meta.jsonConfig['drilldown']` → push `ScreenView(metaId: drilldown.meta_id, fixed: actionParams)`
    - else the edit form if allowed
    - else the read-only form
  - ⋯/long-press → a bottom sheet of `rowActions`:
    - `edit` → openForm(recordId)
    - `delete` → confirm, then DELETE `/metas/{form}/data/{id}`
    - `stage_query` → runStageQuery(form_meta_id)
    - `form` / other → openForm(form_meta_id, defaults: actionParams)
    - Unknown kinds show the "Open on the web" text.
  - `footer` aggregates show as a one-line summary above the list when non-empty.
  - `missingFilters` non-empty → "Choose a filter first: <labels>" and the filter sheet opens.

- [ ] **Step 1: Write failing tests:**
  - `toQuery puts filters and scope under their keys and drops empty`
  - `rowActions hides delete without delete permission and keeps Complete` (fixture: the work orders actions 245–248 from the spec)
  - `actionParams maps id and =text`
  - `grid shows missing filters message and opens the sheet` (widget test, mocked page with `missing_filters: ['status']`)
  - `grid loads page 2 on scroll end` (widget test)
- [ ] **Step 2: Run `flutter test test/grid`.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `flutter test`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: grid as cards with search, filters, buttons and stage queries`

---

### Task 8: Form screen: fields, defaults, layout groups, save, errors

**Files:**
- Create: `lib/form/values.dart`, `lib/form/errors.dart`, `lib/form/fields.dart`, `lib/form/form_screen.dart`, `test/form/values_test.dart`, `test/form/errors_test.dart`, `test/form/form_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 3 (`sessionValue`), 6.
- Produces:
  - `typedef Values = Map<String, Object>`: values are String or bool, as on the web.
  - `Values initialValues(List<MetaParam> params, {Map<String,dynamic>? record, Map<String,String> fixed, Map<String,String> defaults, String? Function(String path) session, DateTime? now})`, ported from `render/formValues.ts`:
    - default_value tokens `{today}` → yyyy-MM-dd, `{now}`, and `{path}` → the session value
    - fixed wins over defaults, defaults win over default_value
    - a record wins over everything except fixed
    - Params of data_type `detail`, `singlefile`, `multifile` and widgets are skipped here (later plans).
  - `Map<String,dynamic> toPayload(List<MetaParam> params, Values v, {required int? appMetaId})`, ported from `formValues.ts toPayload`:
    - numbers are stripped of grouping commas
    - empty → null
    - booleans stay booleans
    - `_context: {app_meta_id}`
  - `List<String> missingRequired(List<MetaParam> params, Values v, Set<String> hidden)`
  - `class FieldErrors {String? banner; Map<String,String> byField;}`
  - `FieldErrors mapErrors(ApiError e, Set<String> fieldsOnScreen)`: keys on screen go to `byField` (first message). Everything else, plus `e.message`, goes to the banner.
  - `Widget FieldInput({required MetaParam p, required Object? value, required ValueChanged<Object> onChanged, String? error, bool readOnly})`, one switch over data_type/render_type, matched to the web `FormView.tsx` field switch:
    - text
    - textarea (multi-line)
    - integer/decimal/money (`TextInputType.numberWithOptions(decimal:)`)
    - date/datetime (`showDatePicker`/`showTimePicker`)
    - select/status (options from `jsonConfig['options']`, a bottom sheet list)
    - boolean (Switch)
    - lookup (a read-only field showing `lookupText` that opens `pickLookup`)
    - Any other type shows the value read-only with the "Open on the web" hint.
  - `Future<bool> openForm(BuildContext, {required int formMetaId, Object? recordId, Map<String,String> fixed = const {}, Map<String,String> defaults = const {}, bool readOnly = false})`
- `FormScreen` behaviour:
  - One field per row, full width.
  - Groups follow `meta.jsonConfig['layout']`: sections → headed sections; tabs → `TabBar`; wizard → steps with Next checking required, as in the web. Read `FormView.tsx` for the exact layout shape. A param's group comes from `jsonConfig['group']`.
  - Fixed fields are hidden but sent.
  - Autonumber fields show the preview from GET `/metas/{id}/autonumber?values[...]` and stay read-only.
  - A sticky bottom bar has Save, plus "Save and add" when the web form offers it (read the web form's flag).
  - Before sending, check `missingRequired`.
  - POST `/metas/{id}/data` creates and PUT `/metas/{id}/data/{rid}` updates.
  - A 422 goes through `mapErrors`.
  - On success, pop with true and show a snackbar.

- [ ] **Step 1: Write failing tests:**
  - `initialValues fills {today} and session tokens` (now = 2026-11-07 → `2026-11-07`; `{sessionemployeeid}` → `'42'`)
  - `fixed beats record beats default_value`
  - `toPayload strips commas, empties to null, adds _context`
  - `missingRequired skips hidden fields`
  - `mapErrors puts unknown and line keys in the banner` (keys `title`, `lines.0.qty`, `zzz` with title on screen → byField {title}, banner contains the message of lines.0.qty)
  - `work order form shows required marks and blocks save until filled` (widget test with the work order form params from the spec, mocked API)
- [ ] **Step 2: Run `flutter test test/form`.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `flutter test`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: native forms with defaults, groups, save and errors`

---

### Task 9: On the phone: the Assets app end to end (local backend)

**Files:**
- Modify: `README.md` (build, install, how the phone reaches the local backend)

- [ ] **Step 1:** Connect the user's phone over USB (USB debugging on). `adb devices` shows it.
- [ ] **Step 2:** `dart run tool/build_app.dart --app 160 --api <the local URL chosen in Task 1>`, then `flutter install` (or `flutter run --dart-define=…` for logs).
- [ ] **Step 3:** Check on the phone and note each result in the README's "Checked" section:
  1. Splash shows "Assets" in the app colour, and sign-in works with a local user.
  2. Bottom tabs = Asset register, Transfers, Work orders, More. More lists the rest under their groups, and unsupported screens (dashboard, calendar, workspace, statements) are absent.
  3. Asset register: cards show title/tag/status chip. Tapping one opens its drilldown, the asset workspace, which shows "Open on the web" until plan 3. Search "pump" narrows the list. The filter sheet with Status = idle works, and its chip removes it.
  4. Work orders: Add opens the form, the autonumber preview shows, Asset is picked through the lookup, and Save creates a record that appears in the list.
  5. Long-press a work order: Complete opens the stage-query sheet, Check shows the row count, and Run completes it (status changes).
  6. Edit and Delete respect permissions (sign in as a non-admin user with view-only on work orders: no Add, no Edit/Delete).
  7. Turn on airplane mode, then pull to refresh: the "server could not be reached" message shows with Retry.
- [ ] **Step 4:** If something fails, fix it in the owning task's files with a test, then re-check.
- [ ] **Step 5: Commit** `docs: part 1 checked on a phone`
