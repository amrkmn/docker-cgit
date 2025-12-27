#!/bin/sh
# Chroma syntax highlighting filter for cgit
# Supports 200+ languages with modern framework support (Svelte, Astro, SolidJS, Qwik, etc.)
#
# Usage: chroma-highlight.sh filename < file
#
# Features:
# - 200+ language support via Chroma
# - Dark theme compatible (monokai style)
# - HTML table output for cgit compatibility

CHROMA="${CHROMA_BIN:-/usr/local/bin/chroma}"
THEME="${CHROMA_THEME:-monokai}"

# Get filename from argument
FILENAME="$1"

# Read source code from stdin
CODE=$(cat)

# Get file extension for auto-detection
EXT="${FILENAME##*.}"

# Chroma options:
# --html: Output as HTML
# --html-only: Output HTML fragment (no header/footer)
# --style: Color theme
# --lexer: Language (auto-detect if not specified)
# --html-tab-width: Tab width in spaces
# --html-styles: Include CSS styles inline

if [ -n "$EXT" ]; then
    echo "$CODE" | "$CHROMA" --html --html-only --style="$THEME" --html-tab-width=4 --lexer="$EXT" --html-styles
else
    echo "$CODE" | "$CHROMA" --html --html-only --style="$THEME" --html-tab-width=4 --html-styles
fi
