cask "murmur" do
  version ":auto_bump_version:"
  sha256 ":auto_bump_sha256:"

  url "https://github.com/roshanshah11/murmur/releases/download/v#{version}/Murmur-#{version}.dmg",
      verified: "github.com/roshanshah11/murmur/"
  name "Murmur"
  desc "Local-first macOS voice typing — double-tap fn, speak, paste"
  homepage "https://github.com/roshanshah11/murmur"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "Murmur.app"

  zap trash: [
    "~/Library/Application Support/Murmur",
    "~/Library/Logs/Murmur",
    "~/Library/Caches/Murmur",
    "~/Library/Preferences/com.murmur.app.plist",
    "~/Library/Saved Application State/com.murmur.app.savedState",
    "~/Library/HTTPStorages/com.murmur.app",
    "~/Library/HTTPStorages/com.murmur.app.binarycookies",
  ]
end
