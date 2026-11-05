# F4 for Raycast

Search the memes in your meme folder from Raycast and copy or paste one. It reads the same folder as the F4 app (F4's library in `~/Library/Application Support/F4/Memes` by default, or the folder picked in the app; any folder you pick in the extension preferences wins), including subfolders.

Memes are copied as files, never as decoded images, so GIFs stay animated when you paste them into Slack, Discord or Telegram.

## Develop

```bash
cd raycast
npm install
npm run dev
```
