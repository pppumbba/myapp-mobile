# myapp-mobile

Android app for one Wand **app meta**. The screens are the frontend's `mobile.html`
(`myapp-frontend/frontend/src/mobile`), built for that app and wrapped with Capacitor 8.
There is no builder on the phone.

## Set up an app

On the app meta, open **Phone app**, turn it on and give it a name, a package id
(e.g. `mn.wand.eam_app`) and a colour.

## Build

```sh
npm install
npm run build -- --app 160                 # production API
npm run build -- --app 160 --api http://myapp-backend.test/api --customer acme
npm run open                               # Android Studio
npm run apk                                # debug APK in android/app/build/outputs/apk
```

`--frontend` (or `MYAPP_FRONTEND`) points at the frontend if it isn't in `../myapp-frontend/frontend`.

Needs JDK 21 and the Android SDK for the APK. The backend must allow the phone's origin
(`MOBILE_ORIGINS`, default `https://localhost,capacitor://localhost`), and Centrifugo needs
`https://localhost` in its allowed origins.
