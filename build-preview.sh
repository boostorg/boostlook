#!/bin/sh
# Build preview site from website-v2-docs and swap in boostlook-v3.css
#
# Usage:
#   ./build-preview.sh            # build lib docs + site docs, sync into preview/
#   ./build-preview.sh --css-only # just rebuild CSS and swap it in
#   ./build-preview.sh --serve    # just start the local server

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCS_DIR="$SCRIPT_DIR/../website-v2-docs"
BOOST_DIR="$HOME/boost"
PREVIEW_DIR="$SCRIPT_DIR/preview"
BUILD_DIR="$DOCS_DIR/build"
PORT=8000

css_swap() {
  echo "Swapping boostlook-v3.css into preview..."
  cp "$SCRIPT_DIR/boostlook-v3.css" "$PREVIEW_DIR/_/css/boostlook.css"
}

serve() {
  echo "Serving preview at http://localhost:$PORT/"
  open "http://localhost:$PORT/"
  cd "$PREVIEW_DIR"
  python3 -m http.server "$PORT"
}

if [ "$1" = "--serve" ]; then
  serve
  exit 0
fi

if [ ! -d "$DOCS_DIR" ]; then
  echo "Error: website-v2-docs not found at $DOCS_DIR"
  exit 1
fi

if [ ! -d "$BOOST_DIR" ]; then
  echo "Error: boost superproject not found at $BOOST_DIR"
  exit 1
fi

# Rebuild CSS from sources
echo "Building boostlook-v3.css..."
sh "$SCRIPT_DIR/build-css.sh"

if [ "$1" = "--css-only" ]; then
  css_swap
  echo "Done (CSS only)."
  exit 0
fi

# Build library docs
echo "Building library docs..."
cd "$DOCS_DIR"
sh libdoc.sh develop

# Build site docs
echo "Building site docs..."
sh sitedoc.sh develop

# Sync capy library docs into preview/capy/
echo "Syncing capy docs into preview..."
mkdir -p "$PREVIEW_DIR/capy"
rsync -a --delete "$BUILD_DIR/lib/doc/capy/" "$PREVIEW_DIR/capy/"

# Sync UI assets (fonts, JS, images)
echo "Syncing UI assets..."
rsync -a "$BUILD_DIR/lib/doc/_/" "$PREVIEW_DIR/_/"

# Sync site docs
echo "Syncing site docs..."
for dir in user-guide contributor-guide formal-reviews; do
  if [ -d "$BUILD_DIR/$dir" ]; then
    rsync -a "$BUILD_DIR/$dir/" "$PREVIEW_DIR/$dir/"
  fi
done

# Build charconv (asciidoctor + b2)
echo "Building charconv docs..."
cp "$SCRIPT_DIR/boostlook-v3.css" "$BOOST_DIR/tools/boostlook/boostlook.css"
cd "$BOOST_DIR/libs/charconv/doc"
"$BOOST_DIR/b2" html_
mkdir -p "$PREVIEW_DIR/charconv"
cp "$BOOST_DIR/libs/charconv/doc/html/charconv.html" "$PREVIEW_DIR/charconv/index.html"

# Swap in our CSS
css_swap

echo "Done. Preview ready at preview/"

# Start local server
serve
