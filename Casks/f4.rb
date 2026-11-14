# Homebrew tap hosted in the F4 repo itself:
#   brew tap kkratterf/f4 https://github.com/kkratterf/f4
#   brew install --cask f4
# version and sha256 are bumped by .github/workflows/release.yml after each
# stable release.
cask "f4" do
  version "0.8.1"
  sha256 "4f5e1e9497af53e43e5dba4b88fb2db6602e63e2a7bee11b0bc9bebb4a72afca"

  url "https://github.com/kkratterf/f4/releases/download/v#{version}/F4-#{version}.dmg"
  name "F4"
  desc "Spotlight-like launcher that copies memes and GIFs to the clipboard"
  homepage "https://f4.kkratter.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sonoma

  app "F4.app"

  uninstall quit: "com.kkratterf.f4"

  zap trash: [
    "~/Library/Caches/com.kkratterf.f4",
    "~/Library/HTTPStorages/com.kkratterf.f4",
    "~/Library/Preferences/com.kkratterf.f4.plist",
    "~/Library/Saved Application State/com.kkratterf.f4.savedState",
  ]

  caveats <<~EOS
    Paste or drop your memes into the panel: they go in F4's library (or any folder you pick from the menu bar).
  EOS
end
