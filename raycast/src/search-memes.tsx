import {
  Action,
  ActionPanel,
  Clipboard,
  Grid,
  Icon,
  closeMainWindow,
  getPreferenceValues,
  showHUD,
  showToast,
  Toast,
} from "@raycast/api";
import { useEffect, useState } from "react";
import { Meme, memeFolder, scanMemes } from "./memes";

interface Preferences {
  folder?: string;
  primaryAction?: "copy" | "paste";
}

/**
 * Copies the file itself, never a decoded image: Raycast puts the file URL on
 * the pasteboard, so Slack, Discord and Telegram upload the animated GIF.
 */
async function copy(meme: Meme) {
  await Clipboard.copy({ file: meme.path });
  await closeMainWindow();
  await showHUD(`Copied ${meme.name}`);
}

async function paste(meme: Meme) {
  await Clipboard.paste({ file: meme.path });
  await closeMainWindow();
}

export default function SearchMemes() {
  const preferences = getPreferenceValues<Preferences>();
  const folder = memeFolder(preferences.folder);
  const [memes, setMemes] = useState<Meme[]>();
  const [error, setError] = useState<string>();

  useEffect(() => {
    scanMemes(folder)
      .then(setMemes)
      .catch((reason: unknown) => {
        const message = reason instanceof Error ? reason.message : String(reason);
        setError(message);
        setMemes([]);
        showToast({ style: Toast.Style.Failure, title: "Can't read the meme folder", message });
      });
  }, [folder]);

  const pasteFirst = preferences.primaryAction === "paste";

  return (
    <Grid columns={5} inset={Grid.Inset.Small} isLoading={memes === undefined} searchBarPlaceholder="Cerca un F4 basito...">
      {memes?.length === 0 && (
        <Grid.EmptyView
          icon={error ? Icon.Warning : "icon.png"}
          title={error ? "Can't read the meme folder" : "F4. Basito. No memes yet"}
          description={error ?? `Drop GIFs, stickers and JPEGs into ${folder}.`}
        />
      )}
      {memes?.map((meme) => {
        const copyAction = <Action title="Copy Meme" icon={Icon.Clipboard} onAction={() => copy(meme)} />;
        const pasteAction = <Action title="Paste Meme" icon={Icon.Text} onAction={() => paste(meme)} />;
        return (
          <Grid.Item
            key={meme.path}
            content={{ source: meme.path }}
            title={meme.name}
            subtitle={meme.category}
            keywords={meme.category ? meme.category.split("/") : undefined}
            accessory={meme.isGIF ? { icon: Icon.Play, tooltip: "GIF" } : undefined}
            actions={
              <ActionPanel>
                {pasteFirst ? pasteAction : copyAction}
                {pasteFirst ? copyAction : pasteAction}
                <Action.ShowInFinder path={meme.path} />
                <Action.CopyToClipboard
                  title="Copy File Path"
                  content={meme.path}
                  shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </Grid>
  );
}
