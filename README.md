# BoostLook

A set of stylesheets, templates, and code for Asciidoctor and Antora rendered documentation to give it a uniform look and feel befitting the quality of Boost.

## Integration

Example integration into a doc Jamfile:
```jam
html mp11.html : mp11.adoc
    :   <use>/boost/boostlook//boostlook
        <dependency>mp11-docinfo-footer.html
    ;
```

## Development

For CSS development, testing, and preview workflows, see **[DEVELOPMENT.md](DEVELOPMENT.md)**:

- **Preview with AsciiDoc**: Quick CSS testing with simple AsciiDoc files
- **Preview with Antora**: Production testing with real Boost documentation content
- Setup instructions, prerequisites, and troubleshooting

## Font License

Noto font files are covered under the Open Font License: https://fonts.google.com/noto/use

## Files

- `boostlook.css` - Main stylesheet
- `boostlook.rb` - Antora extension
- `boostlook_asciidoc_preview.rb` - AsciiDoc preview script
- `boostlook_antora_preview.rb` - Antora preview script
- Font files: `*.woff`, `*.woff2`, `*.ttf`
