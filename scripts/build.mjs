// Builds the phone app for one app meta:
//   npm run build -- --app 160 [--customer acme] [--api https://host/api]
// 1. asks GET /api/[c/{customer}/]mobile/{app} for its name, package id and colour;
// 2. builds the frontend's mobile.html with VITE_MOBILE_APP / VITE_MOBILE_CUSTOMER / VITE_API_BASE_URL into www/;
// 3. writes app.json (read by capacitor.config.ts and android/app/build.gradle) and runs cap sync.
import { execSync } from 'node:child_process';
import { existsSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { parseArgs } from 'node:util';

const root = resolve(import.meta.dirname, '..');
const { values: args } = parseArgs({
  options: {
    app: { type: 'string' },
    customer: { type: 'string' },
    api: { type: 'string', default: process.env.MOBILE_API ?? 'https://5-223-38-162.sslip.io/api' },
    frontend: { type: 'string', default: process.env.MYAPP_FRONTEND ?? resolve(root, '../myapp-frontend/frontend') },
  },
});
if (!/^\d+$/.test(args.app ?? '')) {
  console.error('Usage: npm run build -- --app <app meta id> [--customer <code>] [--api <url>]');
  process.exit(1);
}

const api = args.api.replace(/\/+$/, '');
const url = `${api}${args.customer ? `/c/${args.customer}` : ''}/mobile/${args.app}`;
const res = await fetch(url, { headers: { Accept: 'application/json' } });
if (!res.ok) {
  console.error(`${url} answered ${res.status}: ${(await res.text()).slice(0, 300)}`);
  process.exit(1);
}
const info = await res.json();
if (!info.package_id) {
  console.error(`App ${args.app} has no package id; set it in the app meta's Phone app panel.`);
  process.exit(1);
}
const customer = args.customer ?? info.customer?.code ?? '';
console.log(`Building ${info.name} (${info.package_id}) from ${api}${customer ? `, customer ${customer}` : ''}`);

// Only mobile.html is needed; it becomes www/index.html, the page Capacitor opens.
const www = resolve(root, 'www');
execSync(`npx vite build --outDir "${www}" --emptyOutDir`, {
  cwd: args.frontend,
  stdio: 'inherit',
  env: { ...process.env, VITE_API_BASE_URL: api, VITE_MOBILE_APP: args.app, VITE_MOBILE_CUSTOMER: customer },
});
rmSync(resolve(www, 'index.html'), { force: true });
renameSync(resolve(www, 'mobile.html'), resolve(www, 'index.html'));

const color = /^#[0-9a-f]{6}$/i.test(info.color ?? '') ? info.color : '#4f46e5';
writeFileSync(resolve(root, 'app.json'), JSON.stringify({ appId: info.package_id, appName: info.name, color }, null, 2) + '\n');

// android/app/build.gradle reads app.json for the applicationId and name, so android/ stays the same for every app.
if (existsSync(resolve(root, 'android'))) {
  execSync('npx cap sync android', { cwd: root, stdio: 'inherit' });
} else {
  console.log('No android/ project yet: run "npx cap add android" once, then build again.');
}
