# Flutter phone app for app metas: design

Date: 2026-11-07. Repo: `myapp-mobile` (replaces the Capacitor shell committed today as 3aed775).

## Why

Making the web app smaller doesn't give a phone app. A web screen on a phone has:
- **Menus** with groups inside groups (parent → child).
- **Datagrids** with rows and columns.
- **Toolbars** of action buttons above the grid.
- **Filters** in a sidebar.

None of these work on a phone. The user wants a **separate Flutter app** that draws the same app metas with real phone screens. An app is built once as metas and works on the web and on the phone.

The first users are **technicians using the EAM "Assets" app** (meta 160, `eam_app`). They look up assets and record work in the field. Both matter equally: finding a record fast, and filling in a form quickly while standing.

## Goals

1. **One Android app per app meta**, decided earlier:
   - It uses `json_config.mobile` {enabled, name, package_id, color} on the app meta. This already exists, along with `GET /api/mobile/{meta}`.
   - It opens straight into that app.
2. **These meta kinds work natively** (the user's list):
   - **datagrid**, shown as **cards**
   - **form**, with every field type and **form scripts**
   - **workspace**
   - **tabs**
   - **dashboard**
   - **chart**
   - **calendar**
   - **lines inside lines** (detail params, up to 3 levels)
   - **one-to-one details**
   - **file attachments** (singlefile / multifile)
3. **Form scripts behave as on the web.** The same JS on the meta (load, event, before_save, after_save, var_fnc) runs on the phone with the same helpers.
4. **Grid buttons work:** add, edit, delete, plus buttons that run a stage query or open a form (e.g. work order **Complete**). Drilldowns work too (asset register → asset workspace).
5. **Builders get phone settings on metas** (see "Phone settings"). With nothing set, the phone works out a sensible screen from the existing metas.
6. **The same rules as the web:**
   - permissions (`/user/access`: can view/create/edit/delete)
   - criteria on details
   - session values
   - translations (Accept-Language / users.locale)
   - customer schemas

## Non-goals (this version)

- Statements, report/PDF documents and document fields, Excel import/export, matrix tables, tree grids, query-builder screens, record history, stage queries run by hand from the menu, gantt, page/widget metas, website metas.
- Messenger and notifications. The user didn't ask for them. They can come later.
- Offline use. Users always have a signal, so there's no local database or sync.
- iOS (needs a Mac). Google sign-in, push (FCM) and Play signing come in a later part.
- Any builder or designer screen on the phone.

## Anti-goals (a failure even if it technically works)

- **Desktop leftovers on the phone:**
  - a table squeezed onto the screen
  - a button toolbar on top of the list
  - filters taking up space before the records
  - a menu you have to dig through
- **Scripts that act differently than on the web.** Then builders have to write two versions.
- **An app that works on the phone only after a builder has set phone settings.** The settings refine the screens. They must never be required.
- **Duplicated business rules.** The server stays the place where saving, validation, autonumbers, process flows, totals and notifications happen. The phone only collects input and shows results.

## How it's made

**Decided by the user:**
- Flutter, a separate app (not a WebView).
- Android first.
- One app per app meta.
- Bottom tabs + More.
- Phone settings live on metas.

**My calls** (the builder may revisit them if one blocks):
- **Flutter:** current stable, Dart 3.
- **State:** Riverpod.
- **Routing:** go_router.
- **HTTP:** dio.
- **Storing the token:** flutter_secure_storage.
- **Charts:** fl_chart.
- **Calendar:** table_calendar.
- **Attachments:** image_picker (camera/gallery) and file_picker.
- **JS engine for form scripts:** flutter_js (QuickJS on Android). It supports async functions and promises, which `fill()` needs.
- **Per-app build:** the same approach as the Capacitor version.
  - A script (`tool/build_app.dart` or a small Node/PowerShell script) reads `/api/mobile/{id}` and writes an ignored `app.json`.
  - `android/app/build.gradle` reads `app.json` for `applicationId` and the app name, so the committed project never changes per app.
  - The app id, customer code and API base reach Dart through `--dart-define` (`APP_META_ID`, `CUSTOMER_CODE`, `API_BASE`).
- **Branding:** the app colour drives the Material 3 colour scheme (`ColorScheme.fromSeed`). The launcher icon is generated from the colour (flutter_launcher_icons), or left as the default if generating is difficult.
- **The Capacitor files in `myapp-mobile`** (package.json, capacitor.config.ts, scripts/build.mjs, android/) are removed and replaced by the Flutter project in the same repo.
- **The browser phone version** (`mobile.html`, `src/mobile/*`, still uncommitted in myapp-frontend):
  - It isn't needed once Flutter works.
  - Keep the parts that are useful to the web anyway: the backend `MobileController` and the "Phone app" panel. Ask the user before deleting the rest.

## The app

### Start and sign-in
1. **Splash:** reads `/api/mobile/{APP_META_ID}` (name, colour, customer).
2. **Sign in:** email + password, `POST /api/login`. The bearer token goes in secure storage.
3. **Customer:**
   - Requests use the `/c/{code}` prefix the same way `lib/api.ts` `withCustomer` does.
   - After login the app uses the customer from `CUSTOMER_CODE` (`POST /customers/{id}/use` as the web /start does).
   - A user with no access to that customer sees a clear message.
4. **Loaded after login:** `GET /user` (locale), `GET /user/access` (permissions), `GET /user/session` (session values), then the app meta and its params.

### Navigation
- The app meta's params are its menu tree. The phone **flattens** it:
  - **Bottom tabs:** the first 4 visible screens, or the ones chosen in the app's phone settings. If there are more, the 4th tab is **More**.
  - **More:** a list of the remaining screens under plain group headings, one level deep, never a tree.
- **Left out of the menu:**
  - screens the user can't view
  - screens hidden for the phone
  - screens whose kind isn't supported
- **Top bar:** the screen name, a back arrow on pushed pages, and an account sheet (name, customer, language, sign out).

### Datagrid → cards
- **Reads** `GET /metas/{id}/data` with paging (infinite scroll), `q` search, `filter[...]`, `scope[...]`, and sort, as the web GridView does.
- **Card slots**, in this order of precedence:
  1. the grid's phone settings
  2. the web card slots it already has (`meta_params.widget_position`: image / title / subtitle / badge / body / footer)
  3. a guess: the `is_label` param is the title, the next shown param is the subtitle, a status-render param is the badge, and up to 3 more shown params go in the body as "Label: value"
- **Values** are formatted like the web `Cell`: money, dates, lookups via display_field, status colours, files as a paperclip and count.
- **Search box** at the top.
- **Filter button** opens a bottom sheet with the `is_criteria` params, using the same inputs as forms and the same `filter_as` lookups. Facet counts come from `/metas/{id}/facets` where the web uses them. Active filters show as chips under the search.
- **Add** is a floating round button when the user can create.
- **Tap a card:**
  - if the grid has a drilldown, it opens the drilldown target
  - otherwise, if the user can edit, it opens the edit form
  - otherwise it opens a read-only view of the record
- **Long-press or ⋯ on a card** opens the row buttons (`meta_actions` with `show_in_row`). Edit, delete and custom buttons follow the same rules as the web: `needs_row`, `params` mapping, `form_meta_id`, stage_query buttons.
- **Delete** asks for confirmation.
- **Stage-query buttons** (e.g. Complete) work as on the web (`StageQueryDialog` / `StageQueryView`), in a bottom sheet: an input for each of the query's params with its mapped defaults, a dry run that says how many rows would change, then confirm and run. This follows the user's rule that what works on the web works on the phone.
- **Footer aggregates** (`json_config.aggregate`) show as a small summary bar above the list, if the grid has them.
- **Pull to refresh.**
- **Grids that reuse another grid** (`ref_meta_id → datagrid`) read their effective definition the way the web does (`?effective=1`).

### Form
- **Definition and data:**
  - The form's params give one full-width field per row.
  - Field groups follow `json_config.layout` (sections / tabs / wizard) and the param `json_config.group`, as in the web FormView.
  - Field order is order_number, unless the phone settings (`order`) say otherwise.
  - Opening an existing record uses `GET /metas/{id}/data/{rid}`. New records use defaults: `default_value` with `{today}`, `{path}` session tokens, and presets/fixed values from the screen or scope that opened the form.
  - Autonumber preview comes from `/metas/{id}/autonumber`.
  - Get/fill uses `/metas/{id}/fill`.
- **Inputs, matched to data_type / render_type** (use the web `FormView` / `formValues.ts` as the spec):
  - text and textarea
  - number, decimal and money (number keyboard)
  - date and datetime (native pickers)
  - select / options
  - status
  - boolean
  - **lookup:** a full-screen searchable list from the lookup grid, using display_field / value_field. It supports the multi-pick basket where the web has it (`onPickMany` for detail lines).
  - singlefile / multifile
  - read-only computed totals
- **Required and validation:**
  - Required fields are marked and checked before sending.
  - Server 422 errors map back to fields, including line errors keyed like `lines.0.deliveries.1.quantity`.
- **Save:**
  - A sticky Save button at the bottom.
  - The body follows the same payload rules as the web (`toPayload` / `linesPayload` / `detailPayload`, `_context.app_meta_id`).
  - "Save and add" if the form offers it on the web.
- **Details (lines):**
  - Each detail param is a section listing its lines as compact cards. Tap a line to edit it in a pushed page or a sheet, which is its own form. The line's own details appear the same way below it, up to 3 levels.
  - Add line, remove line, and the multi-pick "Choose" button work as on the web.
  - Line amounts and totals (`json_config.amount`, total_field) are computed live as on the web. The server still re-sums on save.
- **One-to-one detail** (`json_config.one`): its fields show inline as a section of the form, and it's always saved, as on the web.
- **Detail criteria** (`json_config.criteria`): use a Dart port of `render/criteria.ts`. Sections appear and disappear live, and only applicable ones are sent.
- **File attachments:**
  - The field offers camera, gallery and files, honouring `accept`, `max_size` and `max_files`.
  - Uploads go to `POST /metas/{id}/files` with progress.
  - Each file has a description, can be removed, and can be opened through `/contents/{id}`.

### Form scripts
- They run in flutter_js with **the same helper names and meaning as `render/formScript.ts`**:
  - values, get, set, lines, line, sum, setLine, header.get/set
  - num, round, today
  - hide, show, readonly
  - message, error, `fill(getMetaId, params)` (async; calls the API from Dart)
  - `session(path)`
  - field, value, detail, index, row, mode
- **The same lifecycle:**
  - load runs before the values show
  - event runs after a field changes, with per-line events from a line diff (port `lineChanges`)
  - before_save stops the save on `error()` or `return false`
  - after_save gets the saved row
  - var_fnc is prepended to each script
  - a line form's own event script runs per changed line, then the header event script runs
  - a form with an event script turns off the built-in client total, as on the web
- **The same draft semantics:** the script works on a copy of the form state, and the form takes the changes when the script finishes.
- **A script that throws** shows an error naming the script kind, as the web does. It doesn't crash the form.
- **Shared test fixtures:** a set of script cases (input state → expected state/messages) that the web `formScript.ts` and the Dart runner both pass. Use the PO total script (`ProcurementDemoSeeder::ORDER_FORM_SCRIPTS`) as one case.

### Workspace
- Opened from a drilldown with the record id, or with a record picker if opened from the menu.
- **Header card:** `title_field` plus the `header` fields, read from the record's form (ref_meta_id).
- **Sections:** each section param becomes a swipeable tab. Each tab renders its target (a grid as cards, or a form) with `scope` applied. Scoped fields are hidden and passed as fixed values when adding, e.g. a work order added from an asset's workspace already has that asset.
- **Unsupported targets** (statement, matrix, report) show an "Open on the web" notice in the tab.

### Tabs
- Each visible param that the user can view becomes a swipeable tab rendering its target meta.
- Presets (filters/fixed/defaults from meta maps) apply as on the web.

### Dashboard and chart
- **Dashboard:** its chart params are stacked in one column, in order_number order. Height comes from `json_config.h`, and `w` is ignored on phones.
- **Chart:** reads `GET /metas/{id}/chart` and draws it with fl_chart. It covers the chart types and formats `ChartView.tsx` supports, and uses the app colour's palette (the six `--chart-1..6` roles).
- **Period chips** scroll sideways inside their row, not the page.
- **Tap a bar, point or slice:** follows the chart's drilldown (x, x.from, x.to, range.from, range.to) and pushes the target screen.

### Calendar
- **Configuration:** the calendar meta's `json_config` (start_field, end_field, title_field, colors, item_label), as `CalendarView.tsx` reads it.
- **Layout:** a month view with dots on days, and below it the list of that day's entries as cards.
- **Tap an entry:** opens its record (edit form or drilldown).
- **Add:** a round button to add one (if allowed), defaulting the start to the selected day.

### Anything else
A kind not listed above never appears in the phone menu. When reached through tabs, a workspace or a drilldown, it shows "Open on the web".

## Phone settings (backend + web builder)

Stored as `json_config.mobile` on each meta, so versions carry them with no new tables.

**References (my call, from the review):**
- Params are referenced by **field_path**. Field paths are stable across copy, export/import and patches, where ids are not.
- App menu items that have no field_path get one when they are picked. Otherwise they are referenced by `ref_meta_id`, which MetaTransfer already remaps (keys ending in `_meta_id`).
- Grid buttons have no stable code, so `card_buttons` holds **action ids**.
- Step 7 must teach `MetaTransfer` (export/import and patches) and `MetaCopy` to remap `json_config.mobile.card_buttons` to the new action ids, and to drop ids that don't resolve.

- **Validation:** in `MetaController::validated()` separately, like the app's mobile block today. Nested rules in the main validate() drop other json_config keys.
- **Every key is optional.**

| Meta | Key | Meaning |
|---|---|---|
| app | `tabs: [menu item ref]` | Which menu items become bottom tabs (max 4, in order). Each ref is a field_path, or `{meta_id}` for an item that opens a meta. |
| app | `hidden_items: [menu item ref]` | Menu items left off the phone. |
| datagrid | `title`, `subtitle`, `badge`, `image`: field_path | Card slots. Each falls back to widget_position, then the guess. |
| datagrid | `body: [field_path]` (max 4) | Fields shown as "Label: value" on the card. |
| datagrid | `card_buttons: [action ids]` | Row buttons shown on the card itself. The rest go in the long-press menu. |
| form | `hidden_fields: [field_path]` | Fields not shown on the phone. They are still sent with their default/fixed values. |
| form | `order: [field_path]` | Phone field order. Fields not listed follow in their usual order. |
| any screen kind | `off: true` | Left out of the phone wherever it appears as a menu item or tab. |

- **Web builder:** a "Phone" panel in MetaSettings for app, datagrid and form metas.
  - It extends the existing "Phone app" panel on app metas.
  - It uses pickers over the meta's own params and actions, not free text.
- **Where Used / MetaUsage:** this is a new reference kind (params and actions referenced by id), so it should be added there, as the Where Used notes require.
- **Tests:** backend feature tests for the validation (bad ids/fields → 422, other json_config keys kept).

## Backend changes besides phone settings
- **Expected to be few.** The phone uses the same API as the web.
- **CORS doesn't apply** to a native app. `MOBILE_ORIGINS` can stay for the browser preview.
- **Possible gaps in the API** found while building should be raised with the user, not worked around in the app. An example would be something the web computes client-side that the phone can't reach.

## Testing and checking
- **Dart unit tests:**
  - payload building
  - criteria port
  - line totals
  - form scripts (the shared fixtures)
  - card-slot fallback
- **Widget tests** for the card, form fields and details.
- **End to end on the Assets app, on the local backend only** (the user's decision: no test records on production), on the user's **real Android phone over USB**:
  1. sign in
  2. find an asset by search and by filter
  3. open its workspace
  4. add a work order from it with parts lines and a photo
  5. press Complete
  6. add a meter reading
  7. look at the Overview dashboard and the maintenance calendar
- **Also:** the PO form's scripts (procurement app) on the phone, to prove scripts match the web.
- **The phone has to reach the local backend:** Herd's `myapp-backend.test` doesn't resolve on the phone. Use `adb reverse` or the PC's LAN address for `API_BASE`. The builder picks whichever works.
- **Tools:** the user approved installing the Flutter SDK, the Android SDK and JDK 21 (Java 25 is installed but Gradle needs 21).

## Order of work (each step usable on its own)
1. **Project and basics:**
   - Flutter project and per-app build
   - sign-in and customer
   - navigation
   - grid cards with search, filters and buttons
   - forms with all field types
   - lookups
2. **Form scripts** (JS engine, helpers, shared fixtures).
3. **Workspace and tabs.**
4. **Details:** lines inside lines, one-to-one, criteria.
5. **File attachments.**
6. **Dashboards, charts and calendar.**
7. **Phone settings:** backend, web panel, and the app reading them.

Steps 1–5 together are the technician's day in the Assets app.

## Left to the builder
- Widget structure, folder layout and naming inside the Flutter project.
- Exact visual styling within Material 3 and the app colour.
- How the JS bridge marshals values. Values stay strings/booleans as on the web.
- Paging size, caching of definitions (the web caches SETUP reads until a write/login/locale; something similar is fine).
