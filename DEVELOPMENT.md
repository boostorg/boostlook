# BoostLook CSS Development Guide

This guide covers the workflow for developers working on `boostlook.css` and its integration with Boost documentation systems.

## Table of Contents

- [Overview](#overview)
- [Development Environment Setup](#development-environment-setup)
- [CSS Development Workflows](#css-development-workflows)
  - [AsciiDoc Workflow](#asciidoc-workflow)
  - [Antora Workflow](#antora-workflow)
- [File Structure](#file-structure)
- [CSS Architecture](#css-architecture)
- [Testing Your Changes](#testing-your-changes)
- [Integration Guidelines](#integration-guidelines)
- [Troubleshooting](#troubleshooting)

## Overview

BoostLook provides a unified styling system for Boost documentation that works with both:

1. **AsciiDoc** - Traditional single-document rendering via Asciidoctor
2. **Antora** - Multi-component documentation sites

The main stylesheet `boostlook.css` is designed to work across both systems while maintaining visual consistency.

## Development Environment Setup

### Prerequisites

- **Ruby** (>= 2.7)
- **Node.js** (for Antora)
- **Required Ruby Gems**:
  ```bash
  gem install asciidoctor listen
  ```
- **Required Node Packages**:
  ```bash
  npm install -g @antora/cli @antora/site-generator
  ```
- **Boost.Build (b2)** - Available in PATH

### Project Structure

```
boostlook/
├── boostlook.css               # Main stylesheet
├── boostlook.rb                # Asciidoctor extension
├── boostlook_preview.rb        # AsciiDoc live preview
├── boostlook_antora_preview.rb # Antora live preview
├── doc/
│   ├── specimen.adoc           # Test AsciiDoc document
│   ├── specimen-docinfo-footer.html
│   ├── Jamfile                 # Boost.Build configuration
│   ├── html/                   # AsciiDoc build output
│   └── antora_specimen/        # Antora test site
│       ├── playbook.yml
│       ├── content/
│       └── build/
└── fonts/                      # Noto font files
```

## CSS Development Workflows

### AsciiDoc Workflow

Use this workflow when developing styles for traditional AsciiDoc documentation.

#### 1. Start Live Preview

```bash
cd /path/to/boostlook
ruby boostlook_preview.rb
```

This will:
- Build `doc/specimen.adoc` using Boost.Build
- Open the result in your browser
- Watch for changes to `boostlook.css` and auto-rebuild

#### 2. Edit CSS

- Edit `boostlook.css` in your preferred editor
- Changes are automatically detected and trigger a rebuild
- Refresh your browser to see updates

#### 3. Test Content

- Edit `doc/specimen.adoc` to test different AsciiDoc elements
- The specimen document includes examples of:
  - Headers and sections
  - Code blocks
  - Tables
  - Lists and admonitions
  - Cross-references

#### Monitored Files

The preview script watches these files for changes:
- `boostlook.css`
- `boostlook.rb`
- `doc/specimen.adoc`
- `doc/specimen-docinfo-footer.html`
- `doc/Jamfile`

### Antora Workflow

Use this workflow when developing styles for Antora-based documentation sites.

#### 1. Start Antora Preview

```bash
cd /path/to/boostlook
ruby boostlook_antora_preview.rb
```

This will:
- Build the Antora specimen site (if not already built)
- Copy `boostlook.css` to the build directory
- Open the site in your browser
- Watch for CSS changes and auto-update

#### 2. Edit CSS

- Edit `boostlook.css` in your preferred editor
- Changes are automatically copied to the Antora build
- Refresh your browser to see updates

#### 3. Test with Real Content

The Antora specimen includes:
- **Boost.URL** documentation (complete structure)
- **Specimen component** (test content)
- Navigation between components
- Real-world documentation patterns

#### Features

- **Fast Updates**: Only CSS is copied on changes (no full rebuild)
- **Hash Checking**: Prevents unnecessary updates
- **Multi-component**: Test navigation and component switching

## File Structure

### Core Files

| File | Purpose |
|------|---------|
| `boostlook.css` | Main stylesheet (161KB, 4300+ lines) |
| `boostlook.rb` | Asciidoctor extension and integration |
| `boostlook_preview.rb` | AsciiDoc development server |
| `boostlook_antora_preview.rb` | Antora development server |

### Test Documents

| Path | Purpose |
|------|---------|
| `doc/specimen.adoc` | AsciiDoc test document |
| `doc/antora_specimen/` | Complete Antora test site |
| `doc/antora_specimen/content/url_component/` | Real Boost.URL docs |

## CSS Architecture

### Key Sections

1. **Base Styles** - Typography, colors, layout fundamentals
2. **AsciiDoc Elements** - Styling for `.sect1`, `.listingblock`, etc.
3. **Antora Components** - Navigation, TOC, component switching
4. **Code Highlighting** - Syntax highlighting styles
5. **Responsive Design** - Mobile and tablet adaptations

### CSS Classes

#### AsciiDoc-specific
- `.sect1`, `.sect2`, etc. - Section headers
- `.listingblock` - Code blocks
- `.admonitionblock` - Warnings, notes, tips
- `.tableblock` - Tables

#### Antora-specific
- `.nav-container` - Main navigation
- `.article` - Main content area
- `.toc` - Table of contents
- `.toolbar` - Header toolbar

### Font Integration

The stylesheet includes references to Noto fonts:
- `NotoSansDisplay.ttf` - Display text
- `NotoSansMono.ttf` - Monospace code
- Font files are loaded via `@font-face` declarations

## Testing Your Changes

### Browser Testing

Test your changes across:
- **Chrome/Chromium** - Primary development browser
- **Firefox** - Secondary testing
- **Safari** (macOS) - WebKit compatibility
- **Mobile browsers** - Responsive design

### Content Testing

#### For AsciiDoc
- Headers (h1-h6)
- Code blocks with syntax highlighting
- Tables with various column types
- Lists (ordered, unordered, definition)
- Admonitions (NOTE, TIP, WARNING, etc.)
- Cross-references and links

#### For Antora
- Component navigation
- Multi-level page hierarchy
- Search functionality
- Mobile navigation
- Component switching

### Performance Considerations

- **CSS Size**: Current file is 161KB - consider impact of additions
- **Font Loading**: Ensure fonts load efficiently
- **Mobile Performance**: Test on slower devices

## Integration Guidelines

### Adding New Styles

1. **Follow existing patterns**: Study current CSS organization
2. **Use semantic naming**: `.boost-` prefix for custom classes
3. **Mobile-first**: Add responsive styles appropriately
4. **Test both systems**: Verify in both AsciiDoc and Antora

### Modifying Existing Styles

1. **Test thoroughly**: Changes affect existing documentation
2. **Check specificity**: Avoid overly specific selectors
3. **Maintain consistency**: Keep visual harmony across components

### Version Control

- Commit CSS changes with descriptive messages
- Include screenshots for visual changes
- Test builds before pushing

## Troubleshooting

### Common Issues

#### Preview Script Not Starting
```bash
# Check Ruby installation
ruby -v

# Install missing gems
gem install asciidoctor listen

# Check Boost.Build
which b2
```

#### Antora Build Fails
```bash
# Check Node.js and Antora
node -v
npx antora --version

# Clear build and retry
rm -rf doc/antora_specimen/build
ruby boostlook_antora_preview.rb
```

#### CSS Changes Not Appearing

1. **Clear browser cache**: Hard refresh (Ctrl+F5 / Cmd+Shift+R)
2. **Check file permissions**: Ensure CSS files are writable
3. **Verify file paths**: Check console for 404 errors
4. **Restart preview script**: Stop and restart the Ruby script

#### Font Loading Issues

- Verify font files are present in project root
- Check browser dev tools for font loading errors
- Ensure CORS headers allow font loading (for file:// URLs)

### Debug Mode

Both preview scripts support verbose logging:
```bash
# Add debug logging
RUBY_DEBUG=1 ruby boostlook_preview.rb
```

### Manual Builds

If preview scripts fail, you can build manually:

**AsciiDoc:**
```bash
cd doc
b2
```

**Antora:**
```bash
cd doc/antora_specimen
npx antora playbook.yml
```

## Tips for Efficient Development

1. **Use browser dev tools**: Inspect elements and test CSS changes live
2. **Keep both previews running**: Test AsciiDoc and Antora simultaneously
3. **Use CSS custom properties**: For consistent colors and measurements
4. **Comment your changes**: Help future developers understand your choices
5. **Test edge cases**: Very long titles, nested lists, complex tables

---

For questions or issues, refer to the main [README.md](README.md) or check the project's issue tracker.
