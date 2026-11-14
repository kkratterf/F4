// Renders the moving preview at the top of the README (Resources/readme/demo.webp)
// from the website's hero demo: F4 opens over a chat, finds a sticker and pastes it.
// GitHub cannot play a video committed to the repository, but it plays an
// animated WebP inline. Run it again whenever the hero demo changes.
//
// The page runs on Playwright's fake clock, one frame at a time, so the result
// does not depend on how fast the machine is.
//
// Usage: node scripts/make-readme-previews.mjs
// Needs Playwright with Chromium (npm i -D playwright && npx playwright install chromium)
// and ffmpeg built with libwebp (brew install ffmpeg).

import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'Resources/readme/demo.webp');
const FPS = 12;
const SKIP = 2.2; // the demo in site/site.js starts its first round after 2.2 s
const ROUND = 8.6; // one round: the chat, the panel, typing, the paste

const tmp = mkdtempSync(join(tmpdir(), 'f4-readme-'));
// No WebGL: the hero's gradient is not in the frame.
const browser = await chromium.launch({ args: ['--disable-gpu', '--disable-webgl'] });
try {
  const tab = await browser.newPage({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 1 });
  await tab.clock.install();
  await tab.goto(pathToFileURL(join(root, 'site/index.html')).href);
  await tab.addStyleTag({ content: 'header.top { display: none !important; } * { transition-duration: 0s !important; }' });
  await tab.evaluate(() => document.fonts.ready);
  const mac = tab.locator('[data-demo]');
  await mac.scrollIntoViewIfNeeded();
  await tab.clock.runFor(SKIP * 1000);
  const frames = Math.round(ROUND * FPS);
  for (let i = 0; i < frames; i++) {
    await mac.screenshot({ path: join(tmp, `f${String(i).padStart(4, '0')}.png`) });
    await tab.clock.runFor(1000 / FPS);
  }
  execFileSync('ffmpeg', ['-nostdin', '-v', 'error', '-y', '-framerate', String(FPS), '-i', join(tmp, 'f%04d.png'),
    '-vf', 'scale=720:-1:flags=lanczos', '-an', '-c:v', 'libwebp_anim', '-quality', '70',
    '-compression_level', '6', '-loop', '0', out]);
  console.log(`Wrote Resources/readme/demo.webp (${frames} frames)`);
} finally {
  await browser.close();
  rmSync(tmp, { recursive: true, force: true });
}
