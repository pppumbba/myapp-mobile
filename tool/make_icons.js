// Draws the Wand Studio mark (three descending violet squares, as in the web app's logo.svg) as the
// Android launcher icon: an adaptive vector icon for Android 8+, and PNGs for older versions.
// Run from myapp-mobile: node tool/make_icons.js
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const res = path.join(__dirname, "..", "android", "app", "src", "main", "res");
const violet = [0x4f, 0x39, 0xf6];
// The mark in logo.svg's 512 box: [x, y, size, radius, alpha].
const squares = [
  [56, 56, 170, 12, 1],
  [246, 246, 116, 9, 0.55],
  [382, 382, 74, 6, 0.22],
];

// ---- adaptive icon (vector): 108dp canvas; the mark runs corner to corner, so it is sized to fit the round mask ----
const scale = 44 / 400, offset = 54 - 256 * scale;
const f = (n) => +(n).toFixed(2);
function roundRect(x, y, s, r) {
  return `M${f(x + r)},${f(y)} h${f(s - 2 * r)} a${f(r)},${f(r)} 0 0 1 ${f(r)},${f(r)} v${f(s - 2 * r)} ` +
    `a${f(r)},${f(r)} 0 0 1 -${f(r)},${f(r)} h-${f(s - 2 * r)} a${f(r)},${f(r)} 0 0 1 -${f(r)},-${f(r)} ` +
    `v-${f(s - 2 * r)} a${f(r)},${f(r)} 0 0 1 ${f(r)},-${f(r)} z`;
}
const paths = squares.map(([x, y, s, r, a]) =>
  `    <path android:fillColor="#4F39F6" android:fillAlpha="${a}" android:pathData="${roundRect(offset + x * scale, offset + y * scale, s * scale, r * scale)}"/>`).join("\n");
const foreground = `<?xml version="1.0" encoding="utf-8"?>
<!-- Wand Studio mark; made by tool/make_icons.js -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
${paths}
</vector>
`;
const adaptive = `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
`;
fs.writeFileSync(path.join(res, "drawable", "ic_launcher_foreground.xml"), foreground);
fs.mkdirSync(path.join(res, "mipmap-anydpi-v26"), { recursive: true });
fs.writeFileSync(path.join(res, "mipmap-anydpi-v26", "ic_launcher.xml"), adaptive);
fs.writeFileSync(path.join(res, "values", "ic_launcher_background.xml"),
  `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>\n`);

// ---- legacy PNGs: the mark on a white rounded square, 4x supersampled ----
function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function png(size, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const raw = Buffer.alloc((size * 4 + 1) * size);
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0;
    rgba.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
  }
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}
const inRound = (px, py, x, y, s, r) => {
  if (px < x || py < y || px > x + s || py > y + s) return false;
  const cx = Math.min(Math.max(px, x + r), x + s - r), cy = Math.min(Math.max(py, y + r), y + s - r);
  return (px - cx) ** 2 + (py - cy) ** 2 <= r * r;
};
function draw(size) {
  const ss = 4, out = Buffer.alloc(size * size * 4);
  const u = 512 / size; // logo units per output pixel
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let sy = 0; sy < ss; sy++) for (let sx = 0; sx < ss; sx++) {
      const px = (x + (sx + 0.5) / ss) * u, py = (y + (sy + 0.5) / ss) * u;
      if (!inRound(px, py, 0, 0, 512, 96)) continue; // white tile with rounded corners
      let c = [255, 255, 255];
      for (const [qx, qy, qs, qr, qa] of squares) {
        if (inRound(px, py, qx, qy, qs, qr)) c = c.map((v, i) => v + (violet[i] - v) * qa);
      }
      r += c[0]; g += c[1]; b += c[2]; a += 255;
    }
    const n = ss * ss, i = (y * size + x) * 4, cov = a / 255;
    out[i] = cov ? Math.round(r / cov) : 0; out[i + 1] = cov ? Math.round(g / cov) : 0;
    out[i + 2] = cov ? Math.round(b / cov) : 0; out[i + 3] = Math.round(a / n);
  }
  return png(size, out);
}
for (const [dir, size] of [["mdpi", 48], ["hdpi", 72], ["xhdpi", 96], ["xxhdpi", 144], ["xxxhdpi", 192]]) {
  fs.writeFileSync(path.join(res, `mipmap-${dir}`, "ic_launcher.png"), draw(size));
}
// A 512px copy for the Play listing and anywhere else that wants the mark as an image.
fs.writeFileSync(path.join(__dirname, "..", "assets", "wand_mark.png"), draw(512));
console.log("icons written");
