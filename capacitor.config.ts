import { existsSync, readFileSync } from 'node:fs';
import type { CapacitorConfig } from '@capacitor/cli';

// app.json is written by scripts/build.mjs for the app meta being built; the defaults only matter
// before the first build.
const app = existsSync('app.json')
  ? JSON.parse(readFileSync('app.json', 'utf8'))
  : { appId: 'mn.wand.mobile', appName: 'Wand', color: '#4f46e5' };

const config: CapacitorConfig = {
  appId: app.appId,
  appName: app.appName,
  webDir: 'www',
  android: { backgroundColor: '#ffffff' },
  plugins: {
    SplashScreen: { backgroundColor: app.color, launchShowDuration: 800, showSpinner: false },
    StatusBar: { backgroundColor: app.color, style: 'DARK', overlaysWebView: false },
  },
};

export default config;
