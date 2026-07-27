#!/bin/bash
# Sir Darb's Sniff Counter - Fix & Launch
#
# Double-click this file in Finder to un-block the app (macOS flags
# downloaded, unsigned apps as "damaged") and open it - no typing needed.
#
# If it can't find the app automatically, just drag the app icon
# straight onto THIS file's icon in Finder instead of double-clicking it,
# and it'll use that location directly.

APP_NAME="Sir Darb's Sniff Counter.app"

echo "Sir Darb's Sniff Counter - Fix & Launch"
echo "----------------------------------------"

FOUND=""

# If the app was dragged onto this script's icon, macOS passes its path in $1
if [ -n "$1" ] && [ -d "$1" ]; then
  FOUND="$1"
fi

# Otherwise check the usual places apps end up
if [ -z "$FOUND" ]; then
  CANDIDATES=(
    "/Applications/$APP_NAME"
    "$HOME/Downloads/$APP_NAME"
    "$HOME/Desktop/$APP_NAME"
  )
  for loc in "${CANDIDATES[@]}"; do
    if [ -d "$loc" ]; then
      FOUND="$loc"
      break
    fi
  done
fi

# Last resort: search more broadly under the home folder
if [ -z "$FOUND" ]; then
  echo "Looking for it in your home folder, this may take a moment..."
  SEARCH_RESULT=$(find "$HOME" -maxdepth 4 -iname "$APP_NAME" -type d 2>/dev/null | head -n 1)
  if [ -n "$SEARCH_RESULT" ]; then
    FOUND="$SEARCH_RESULT"
  fi
fi

if [ -z "$FOUND" ]; then
  echo ""
  echo "Couldn't find \"$APP_NAME\" automatically."
  echo "Please drag the app's icon directly onto this file's icon in Finder"
  echo "(not into this window) and it'll pick it up that way instead."
  echo ""
  read -p "Press Enter to close this window..."
  exit 1
fi

echo "Found: $FOUND"
echo "Removing the 'downloaded from the internet' flag..."
xattr -cr "$FOUND"

echo "Opening the app..."
open "$FOUND"

echo ""
echo "All set! This window will close in a few seconds - you can also just close it now."
sleep 4
