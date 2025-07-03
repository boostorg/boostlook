# BoostLook Development Guide

This guide explains how to develop and test BoostLook styling using two complementary preview workflows: simple AsciiDoc testing and production-like Antora testing.

## Overview

BoostLook provides two preview workflows for developing and testing CSS changes:

- **Preview with AsciiDoc**: Fast iteration with simple AsciiDoc files for quick CSS testing
- **Preview with Antora**: Comprehensive testing using real Boost documentation content via Antora Specimen

Both workflows provide automatic file watching, rebuilding, and browser preview to streamline your development process.

## Preview Workflows

### Preview with AsciiDoc

**Use Case**: Rapid CSS iteration and basic styling verification
**Script**: `boostlook_asciidoc_preview.rb`
**Content**: Your local AsciiDoc files (e.g., `doc/specimen.adoc`)
**Build System**: Boost.Build (b2)
**Speed**: Fast, immediate feedback

This workflow monitors AsciiDoc, HTML, and CSS files for changes, automatically rebuilding via Boost.Build and opening the rendered HTML in your browser.

### Preview with Antora

**Use Case**: Realistic testing with actual Boost documentation structure and content
**Script**: `boostlook_antora_preview.rb`
**Content**: Real Boost.URL documentation fetched from GitHub
**Build System**: Antora site generator
**Speed**: More comprehensive, production-like environment

This workflow uses **Antora Specimen** - a testing setup that fetches official Boost.URL documentation and applies your local BoostLook styling, providing a realistic testing environment with actual production content.

## Prerequisites

### Common Requirements
- **Ruby** (>= 2.7 recommended)
- **Listen Gem** – Install via `gem install listen`

### Preview with AsciiDoc Requirements

-   **Asciidoctor Gem**: Install via `gem install asciidoctor`.
-   **Boost.Build (b2)**: Ensure `b2` is installed and available in your system's `PATH`. You can verify this by running `which b2` or `b2 --version`.
-   **Boost.Build Configuration (`user-config.jam`)**: This is a critical step. You must tell Boost.Build where to find your `asciidoctor` executable.
    1.  Find the full path to `asciidoctor` by running:
        ```sh
        which asciidoctor
        ```
        The output will be a path like `/usr/local/bin/asciidoctor`.

    2.  Create or edit the file `user-config.jam` in your home directory (`$HOME/user-config.jam` on Linux/macOS).

    3.  Add the following line to the file, using the path from step 1:
        ```jam
        # Tell Boost.Build where to find the asciidoctor executable
        using asciidoctor : /usr/local/bin/asciidoctor ;
        ```

### Preview with Antora Requirements
- **Node.js** – For Antora CLI
- **Antora CLI** – Install via `npm install -g @antora/cli @antora/site-generator`

## Quick Start

### Preview with AsciiDoc

1. **Install Prerequisites**:
   ```bash
   # Check Ruby installation
   ruby -v

   # Install required gems
   gem install asciidoctor listen

   # Verify Boost.Build availability
   which b2
   ```

2. **Prepare Content**:
   - Place AsciiDoc files in the `doc/` directory
   - Default test file: `doc/specimen.adoc`

3. **Start Preview**:
   ```bash
   # From project root
   ruby boostlook_asciidoc_preview.rb
   ```

4. **Development Workflow**:
   - Edit `boostlook.css` or AsciiDoc files in `doc/`
   - Script automatically detects changes and rebuilds
   - Browser opens automatically with rendered content
   - Refresh browser to see changes

### Preview with Antora

1. **Install Prerequisites**:
   ```bash
   # Install Antora CLI
   npm install -g @antora/cli @antora/site-generator

   # Install Ruby gem for file watching
   gem install listen
   ```

2. **Start Preview** (with automatic setup):
   ```bash
   # Force rebuild and start watching
   ruby boostlook_antora_preview.rb --rebuild
   ```

3. **Development Workflow**:
   - Edit `boostlook.css` → Triggers automatic rebuild
   - Edit `boostlook.rb` → Triggers automatic rebuild
   - View changes in browser (auto-opened)
   - Repeat until styling is perfect

## File Structure

### Preview with AsciiDoc Structure
```
boostlook/
├── boostlook.css                    # Your main CSS file
├── boostlook.rb                     # Antora extension (Ruby)
├── boostlook_asciidoc_preview.rb    # AsciiDoc preview script
└── doc/
    ├── specimen.adoc                # Test AsciiDoc file
    └── ...                          # Other AsciiDoc files
```

### Preview with Antora Structure
```
boostlook/
├── boostlook.css                           # Your main CSS file
├── boostlook.rb                           # Antora extension (Ruby)
├── boostlook_antora_preview.rb            # Antora preview script
└── doc/
    └── antora_specimen/
        ├── playbook.yml                   # Antora configuration
        └── build/                         # Generated site (git-ignored)
            └── site/
                ├── index.html             # Entry point
                └── _/css/
                    └── boostlook.css      # Your CSS (auto-copied)
```

## What You're Testing Against

### Preview with AsciiDoc
- **Content**: Your custom AsciiDoc files
- **Structure**: Simple document structure
- **Elements**: Basic typography, code blocks, tables
- **Speed**: Very fast iteration cycles

### Preview with Antora
- **Content**: Official Boost.URL documentation from GitHub
- **Structure**: Actual Antora-generated documentation
- **Elements**: Real typography, code blocks, tables, navigation, etc.
- **Complexity**: Multi-level navigation, cross-references, production patterns

## Configuration

### AsciiDoc Preview Configuration
The AsciiDoc preview uses your existing Boost.Build configuration. Ensure your `build.jam` or similar build files are properly configured for BoostLook integration.

### Antora Preview Configuration (`doc/antora_specimen/playbook.yml`)
```yaml
site:
  title: Boostlook Antora Specimen
  url: /
  start_page: url::index.adoc

content:
  sources:
    - url: https://github.com/boostorg/url.git
      branches: develop
      start_path: doc

ui:
  bundle:
    url: https://github.com/boostorg/website-v2-docs/releases/download/ui-master/ui-bundle.zip
    snapshot: true

output:
  dir: ./build/site
```

**Key Points:**
- **No git submodules** - Content fetched automatically
- **Remote UI bundle** - Official Boost documentation UI
- **Your CSS overrides** - Applied automatically after build

## Preview Script Features

### AsciiDoc Preview Features
- **File Watching**: Monitors `doc/` directory and root CSS files
- **Automatic Building**: Uses Boost.Build (b2) for rendering
- **Browser Integration**: Opens rendered HTML automatically
- **Cross-platform**: Works on macOS, Linux, Windows

### Antora Preview Features
- **Automatic CSS Override**: Copies your current `boostlook.css` over outdated UI bundle version
- **Smart Rebuilding**: CSS changes trigger full rebuild (processed by Ruby extension)
- **Content Fetching**: Automatically downloads latest Boost.URL documentation
- **File Hash Checking**: Avoids unnecessary rebuilds

## Manual Testing Commands

### Preview with AsciiDoc (Manual)
```bash
# Build once without watching
b2 doc/specimen.html

# Serve locally (if needed)
python -m http.server 8000
```

### Preview with Antora (Manual)
```bash
# Build once without watching
cd doc/antora_specimen
npx antora --fetch playbook.yml

# Copy your current CSS
cp ../../boostlook.css build/site/_/css/boostlook.css

# Serve locally
npx http-server build/site -p 8080
```

## Troubleshooting

### Preview with AsciiDoc Issues

**Error: `error: no generators were found for type 'HTML'`**

- **Cause**: This is the most common issue. It means Boost.Build (`b2`) cannot find the `asciidoctor` executable.
- **Solution**: You must configure your `$HOME/user-config.jam` file. Please follow the instructions in the **"Boost.Build Configuration (`user-config.jam`)"** section under Prerequisites.

**Error: `command not found: b2`**

- **Cause**: The Boost.Build `b2` executable is not in your system's `PATH`.
- **Solution**: Install Boost.Build and ensure its location is added to your `PATH`. Verify with `which b2`.

**Script must be run from the project root**

- **Cause**: The script expects to be run from the main `boostlook/` directory.
- **Solution**: Make sure you are in the project's root directory before running `ruby boostlook_asciidoc_preview.rb`.

**Warnings like `www-browser: not found` or `xdg-open: ... not found`**

- **Cause**: These warnings may appear on some Linux systems if the script cannot find a default command-line web browser.
- **Solution**: These are usually harmless and can be ignored if a graphical browser still opens. To resolve them, you can install a common utility like `xdg-utils` (`sudo apt-get install xdg-utils` on Debian/Ubuntu).

### Preview with Antora Issues

**Build Fails:**
```bash
# Check Antora installation
npx antora --version

# Check if playbook is valid
cd doc/antora_specimen
npx antora playbook.yml --dry-run
```

**CSS Not Updating:**
```bash
# Force complete rebuild
ruby boostlook_antora_preview.rb --rebuild

# Manually verify CSS copy
ls -la doc/antora_specimen/build/site/_/css/boostlook.css
```

**Preview Script Issues:**
```bash
# Check if listen gem is installed
gem list | grep listen

# Install if missing
gem install listen
```

**Node.js/Antora Issues:**
- Ensure Node.js is installed: `node --version`
- Install/reinstall Antora: `
