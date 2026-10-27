// Renders scripts/dmg-background.html to background.png (@1x) and
// background@2x.png in a folder, for scripts/build-dmg.sh.
// Usage: node scripts/render-dmg-background.js <out dir>
//
// Needs Playwright and its Chromium: build-dmg.sh installs them into
// .build/dmg-tools (pinned) when they are missing. The page is drawn with
// reduced motion, so the grainient draws one frame and stops, and the same
// page always gives the same image.

const fs = require("fs");
const path = require("path");
const { pathToFileURL } = require("url");
const { chromium } = require("playwright");

const outDir = process.argv[2];
if (!outDir) {
  console.error("usage: node render-dmg-background.js <out dir>");
  process.exit(2);
}

const page = pathToFileURL(path.join(__dirname, "dmg-background.html")).href;
// Must match the window in build-dmg.sh.
const viewport = { width: 640, height: 448 };

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ args: ["--use-gl=swiftshader", "--ignore-gpu-blocklist"] });
  try {
    for (const [name, scale] of [["background.png", 1], ["background@2x.png", 2]]) {
      const tab = await browser.newPage({ viewport, deviceScaleFactor: scale, reducedMotion: "reduce" });
      await tab.goto(page, { waitUntil: "networkidle" });
      await tab.evaluate(() => document.fonts.ready);
      // Give the shader its frame.
      await tab.waitForTimeout(500);
      const lit = await tab.evaluate(() => !!document.querySelector("canvas.on"));
      if (!lit) console.warn("render-dmg-background: no WebGL frame, using the CSS glow");
      await tab.screenshot({ path: path.resolve(outDir, name), clip: { x: 0, y: 0, ...viewport } });
      await tab.close();
      console.log(`render-dmg-background: wrote ${name}`);
    }
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(`render-dmg-background: ${error.message}`);
  process.exit(1);
});
