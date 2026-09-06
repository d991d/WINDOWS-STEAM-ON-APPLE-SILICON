#!/bin/bash
# Install or roll back to any tagged Whisky release.
#   ./whisky-version.sh                -> list available tags
#   ./whisky-version.sh app-v3.7.0     -> install that release
# Env: APP=/path/to/Whisky.app  REPO=owner/repo
set -euo pipefail

APP="${APP:-/Applications/Whisky.app}"
REPO="${REPO:-frankea/Whisky}"
TAG="${1:-}"

if [ -z "$TAG" ]; then
  echo "available tags in $REPO:"
  curl -fsSL "https://api.github.com/repos/$REPO/releases?per_page=30" \
    | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4
  echo; echo "usage: $0 <tag>"; exit 0
fi

URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/tags/$TAG" \
  | grep -oE '"browser_download_url": *"[^"]+\.(dmg|zip)"' | cut -d'"' -f4 \
  | grep -viE 'source|librar' | head -1)
[ -n "$URL" ] || { echo "no app asset found for $TAG"; exit 1; }

osascript -e 'quit app "Whisky"' 2>/dev/null || true; sleep 2

TMP=$(mktemp -d); FILE="$TMP/$(basename "$URL")"
if [ -d "$APP" ]; then
  OLD=$(defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo unknown)
  echo "current: $OLD -> backing up to \$HOME"
  rm -rf "$HOME/Whisky-backup-$OLD.app"
  ditto "$APP" "$HOME/Whisky-backup-$OLD.app"
fi
curl -fL# "$URL" -o "$FILE"

case "$FILE" in
  *.dmg)
    MNT=$(hdiutil attach -nobrowse -readonly "$FILE" | grep -o '/Volumes/.*' | head -1)
    rm -rf "$APP"; ditto "$MNT/Whisky.app" "$APP"
    hdiutil detach "$MNT" -quiet ;;
  *.zip)
    ditto -x -k "$FILE" "$TMP/x"
    rm -rf "$APP"; ditto "$TMP/x/Whisky.app" "$APP" ;;
esac

xattr -dr com.apple.quarantine "$APP" || true
rm -rf "$TMP"

BID=$(defaults read "$APP/Contents/Info" CFBundleIdentifier)
defaults write "$BID" SUEnableAutomaticChecks -bool false
defaults write "$BID" SUAutomaticallyUpdate  -bool false

echo "done: $(defaults read "$APP/Contents/Info" CFBundleShortVersionString)"
