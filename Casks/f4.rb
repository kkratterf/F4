# Homebrew tap hosted in the F4 repo itself:
#   brew tap kkratterf/f4 https://github.com/kkratterf/f4
#   brew install --cask f4
# version and sha256 are bumped by .github/workflows/release.yml after each
# stable release.
cask "f4" do
  version "0.3.0"
  sha256 "15246d5ddf2c3b9d3f5195f763298ca5f6667157368cf53c83edc315624ab224"

  url "https://github.com/kkratterf/f4/releases/download/v#{version}/F4-#{version}.dmg"
  name "F4"
  desc "Spotlight-like launcher that copies memes and GIFs to the clipboard"
  homepage "https://kkratterf.github.io/f4/"

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
    F4 is not notarized by Apple yet, so macOS may block the first launch.
    Open it once, then click Open Anyway in System Settings > Privacy & Security,
    or run:
      xattr -dr com.apple.quarantine #{appdir}/F4.app

    Your memes go in ~/Pictures/Memes (or any folder you pick in Settings).
  EOS
end
