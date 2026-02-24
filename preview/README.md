# Preview Site

Local preview of Boost documentation with boostlook-v3 CSS applied. Deployed to [boostlook-v3.netlify.app](https://boostlook-v3.netlify.app/).

## Prerequisites

- Node.js 16+ (for Antora)
- [asciidoctor](https://asciidoctor.org/) (`brew install asciidoctor`)
- b2 (from the Boost superproject)
- Python 3 (for local server)

Sibling repos expected at:

```
~/dev/website-v2-docs   # Antora site & library docs
~/boost                 # Boost superproject (for b2/charconv)
```

`~/user-config.jam` must contain:

```
using asciidoctor ;
```

## Building

### Full build

Builds everything (Antora lib docs, site docs, charconv via b2), syncs into `preview/`, swaps in `boostlook-v3.css`, and starts a local server:

```
./build-preview.sh
```

### CSS only

Edit CSS in `src/css/`, then rebuild and swap without re-running Antora/b2:

```
./build-preview.sh --css-only
```

### Serve only

Start the local server without rebuilding anything:

```
./build-preview.sh --serve
```

## Structure

```
preview/
  index.html            Landing page
  style-guide/          Design tokens (colors, typography, spacing)
  capy/                 Boost.Capy library docs (Antora)
  charconv/             Boost.Charconv library docs (Asciidoctor + b2)
  user-guide/           Site docs (Antora)
  contributor-guide/    Site docs (Antora)
  formal-reviews/       Site docs (Antora)
  _/                    Shared assets (fonts, JS, images, CSS)
```

## How it works

1. `build-css.sh` concatenates `src/css/*.css` into `boostlook-v3.css`
2. Antora builds capy + site docs from `website-v2-docs` into its `build/` dir
3. b2 builds charconv HTML from `~/boost/libs/charconv/doc/`, using `boostlook-v3.css` swapped into `~/boost/tools/boostlook/boostlook.css`
4. `rsync` copies built output into `preview/`
5. `boostlook-v3.css` replaces `preview/_/css/boostlook.css` for Antora pages

## Netlify

Netlify deploys from `preview/` on push. The build command in `netlify.toml` only does the CSS swap (Antora/b2 builds are done locally and committed).
