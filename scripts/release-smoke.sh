#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'release smoke: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"
command -v swift >/dev/null 2>&1 || fail "missing dependency: swift"
command -v shasum >/dev/null 2>&1 || fail "missing dependency: shasum"
command -v tar >/dev/null 2>&1 || fail "missing dependency: tar"
command -v hdiutil >/dev/null 2>&1 || fail "missing dependency: hdiutil"
command -v plutil >/dev/null 2>&1 || fail "missing dependency: plutil"

sha="$(git rev-parse --short HEAD)"
platform="$(uname -s)-$(uname -m)"
output_root="${KEYDEX_RELEASE_SMOKE_DIR:-tmp/release-smoke}"
payload_name="keydex-$sha-$platform"
payload_dir="$output_root/$payload_name"
archive_path="$output_root/$payload_name.tar.gz"
checksum_path="$archive_path.sha256"
file_list_path="$output_root/$payload_name.files"
dmg_path="$output_root/$payload_name.dmg"
dmg_checksum_path="$dmg_path.sha256"

mkdir -p "$payload_dir/bin"

swift build -c release --product keydex
swift build -c release --product KeydexApp

cp .build/release/keydex "$payload_dir/bin/keydex"
cp .build/release/KeydexApp "$payload_dir/bin/KeydexApp"
mkdir -p "$payload_dir/Keydex.app/Contents/MacOS"
cp .build/release/KeydexApp "$payload_dir/Keydex.app/Contents/MacOS/KeydexApp"
cat > "$payload_dir/Keydex.app/Contents/Info.plist" <<'INFO_PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>CFBundleExecutable</key>
    <string>KeydexApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.keydex.app</string>
    <key>CFBundleName</key>
    <string>Keydex</string>
    <key>CFBundleDisplayName</key>
    <string>Keydex</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
  </dict>
</plist>
INFO_PLIST
plutil -lint "$payload_dir/Keydex.app/Contents/Info.plist"
chmod +x "$payload_dir/bin/keydex" "$payload_dir/bin/KeydexApp" "$payload_dir/Keydex.app/Contents/MacOS/KeydexApp"

"$payload_dir/bin/keydex" --help >"$payload_dir/keydex-help.txt"
"$payload_dir/bin/keydex" doctor --metadata Tests/Fixtures/metadata.json \
  >"$payload_dir/keydex-doctor-smoke.txt"

{
  printf 'git_sha=%s\n' "$sha"
  printf 'platform=%s\n' "$platform"
  printf 'cli=bin/keydex\n'
  printf 'app=bin/KeydexApp\n'
  printf 'app_bundle=Keydex.app\n'
  printf 'dmg=%s\n' "$dmg_path"
  printf 'dmg_checksum=%s\n' "$dmg_checksum_path"
  printf 'archive=%s\n' "$archive_path"
  printf 'known_limits=unsigned app bundle and unsigned DMG; signing/notarization remain future gates\n'
} >"$payload_dir/manifest.txt"

hdiutil create -volname "Keydex" -srcfolder "$payload_dir/Keydex.app" -ov -format UDZO "$dmg_path"
hdiutil verify "$dmg_path"
shasum -a 256 "$dmg_path" >"$dmg_checksum_path"
shasum -a 256 -c "$dmg_checksum_path" >/dev/null

tar -czf "$archive_path" -C "$output_root" "$payload_name"
shasum -a 256 "$archive_path" >"$checksum_path"
shasum -a 256 -c "$checksum_path" >/dev/null
tar -tzf "$archive_path" >"$file_list_path"

while IFS= read -r archived_path; do
  case "$archived_path" in
    "$payload_name/" | \
    "$payload_name/bin/" | \
    "$payload_name/bin/keydex" | \
    "$payload_name/bin/KeydexApp" | \
    "$payload_name/Keydex.app/" | \
    "$payload_name/Keydex.app/Contents/" | \
    "$payload_name/Keydex.app/Contents/MacOS/" | \
    "$payload_name/Keydex.app/Contents/Info.plist" | \
    "$payload_name/Keydex.app/Contents/MacOS/KeydexApp" | \
    "$payload_name/keydex-help.txt" | \
    "$payload_name/keydex-doctor-smoke.txt" | \
    "$payload_name/manifest.txt")
      ;;
    *)
      fail "archive contains unexpected file: $archived_path"
      ;;
  esac
done <"$file_list_path"

for expected in \
  "$payload_name/bin/keydex" \
  "$payload_name/bin/KeydexApp" \
  "$payload_name/Keydex.app/Contents/Info.plist" \
  "$payload_name/Keydex.app/Contents/MacOS/KeydexApp" \
  "$payload_name/keydex-help.txt" \
  "$payload_name/keydex-doctor-smoke.txt" \
  "$payload_name/manifest.txt"; do
  rg --fixed-strings --quiet -- "$expected" "$file_list_path" ||
    fail "archive is missing expected file: $expected"
done

if rg --quiet -- 'Tests|Fixtures|metadata\.json|credentials\.env' "$file_list_path"; then
  fail "archive contains fixture or metadata paths"
fi

if rg --text --fixed-strings --quiet -- "sk-test-secret" "$payload_dir"; then
  fail "release payload contains fake secret sentinel"
fi

printf 'payload=%s\n' "$payload_dir"
printf 'archive=%s\n' "$archive_path"
printf 'checksum=%s\n' "$checksum_path"
printf 'dmg=%s\n' "$dmg_path"
printf 'dmg_checksum=%s\n' "$dmg_checksum_path"
printf 'file_list=%s\n' "$file_list_path"
echo "release smoke clean"
