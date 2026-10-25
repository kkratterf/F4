import { readdir, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, extname, join, relative, sep } from "node:path";

/** One image in the meme folder, as the F4 app sees it. */
export interface Meme {
  path: string;
  /** File name without the extension. */
  name: string;
  /** Subfolder relative to the meme folder ("reactions/dogs"), or undefined at the top. */
  category?: string;
  isGIF: boolean;
  modified: number;
}

const EXTENSIONS = new Set([".gif", ".png", ".jpg", ".jpeg"]);
/** Same depth as the app (MemeScanner.maxDepth). */
const MAX_DEPTH = 4;

/** `~/Pictures/Memes` unless the user picked another folder; `~` is expanded. */
export function memeFolder(preference?: string): string {
  const folder = preference?.trim();
  if (!folder) return join(homedir(), "Pictures", "Memes");
  return folder.startsWith("~") ? join(homedir(), folder.slice(1)) : folder;
}

/**
 * The GIF, PNG and JPEG files in `folder` and its subfolders, sorted like the
 * app: top-level memes first, then each subfolder, names in Finder order.
 */
export async function scanMemes(folder: string): Promise<Meme[]> {
  const memes: Meme[] = [];
  async function walk(directory: string, depth: number) {
    const entries = await readdir(directory, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name.startsWith(".")) continue;
      const path = join(directory, entry.name);
      if (entry.isDirectory()) {
        if (depth < MAX_DEPTH) await walk(path, depth + 1);
        continue;
      }
      const extension = extname(entry.name).toLowerCase();
      if (!entry.isFile() || !EXTENSIONS.has(extension)) continue;
      const parent = relative(folder, directory);
      memes.push({
        path,
        name: basename(entry.name, extname(entry.name)),
        category: parent ? parent.split(sep).join("/") : undefined,
        isGIF: extension === ".gif",
        modified: (await stat(path)).mtimeMs,
      });
    }
  }
  await walk(folder, 0);
  const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" });
  return memes.sort((a, b) => {
    if (a.category !== b.category) {
      if (!a.category) return -1;
      if (!b.category) return 1;
      return collator.compare(a.category, b.category);
    }
    return collator.compare(a.name, b.name);
  });
}
