# myapp-mobile

Flutter Android app for one Wand **app meta**. It renders the app's metas natively
from the Laravel backend. One APK is built per app; there is no builder on the phone.

## Set up an app

On the app meta, open **Phone app**, turn it on and give it a name, a package id
(e.g. `mn.wand.eam_app`) and a colour.

## Build

Needs Flutter 3.47, JDK 21 and the Android SDK (`flutter doctor`).

```sh
flutter pub get
dart run tool/build_app.dart --app 160                                  # production API, debug APK
dart run tool/build_app.dart --app 160 --customer acme --release
dart run tool/build_app.dart --app 160 --api http://myapp-backend.test/api --no-build   # only write app.json
```

The tool reads `GET <api>[/c/<customer>]/mobile/<id>`, writes `app.json` (package id, name,
colour; git-ignored, read by `android/app/build.gradle.kts`) and runs `flutter build apk` with
`APP_META_ID`, `API_BASE` and `CUSTOMER_CODE` as `--dart-define`. The APK is in
`build/app/outputs/flutter-apk/`.

## Reaching the local backend from a USB phone

- Use the PC's LAN IP: `--api http://<PC LAN IP>/api` (the host must be served by Herd), or
- `adb reverse tcp:8000 tcp:8000`, then in `myapp-backend` run
  `php artisan serve --host=0.0.0.0 --port=8000` and build with `--api http://127.0.0.1:8000/api`.

`http://myapp-backend.test/api` works for the dry run on the PC but is not resolvable from the phone.

## Tests

```sh
flutter test
flutter analyze
```
