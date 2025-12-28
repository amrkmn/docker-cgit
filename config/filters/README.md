# cgit Filters

This directory contains filters used by cgit for rendering various content types.

## Syntax Highlighting Filters

Two syntax highlighting options are available:

### 1. Chroma (Default - Currently Active)

**File:** `chroma-highlight.sh`

**Features:**
- Fast (compiled Go binary)
- 200+ language support
- Modern framework support (Svelte, Astro, SolidJS, Qwik, etc.)
- Dark theme compatible (monokai style)
- Pygments-compatible CSS classes

**Usage in cgitrc:**
```
source-filter=/opt/cgit/filters/chroma-highlight.sh
```

### 2. Pygments (Alternative - Python)

**File:** `syntax-highlighting-dark.py`

**Features:**
- 500+ language support
- Smart lexer detection (filename, shebang, content analysis)
- Dark theme compatible (monokai style)
- Inline CSS injection
- No external binary required

**Usage in cgitrc:**
```
source-filter=/opt/cgit/filters/syntax-highlighting-dark.py
```

**To switch:** Edit `/opt/cgit/data/cgitrc` and change the `source-filter` line.

## Other Filters

### About Filter
**File:** `about-formatting.sh`

Renders README files in multiple formats:
- Markdown (`.md`, `.markdown`) → HTML via Python markdown
- reStructuredText (`.rst`) → HTML via rst2html
- HTML (`.html`) → Pass through
- Plain text → Wrapped in `<pre>` tags

### Email Filter
**File:** `email-libravatar.py`

Displays Libravatar avatars next to author email addresses:
- Privacy-respecting alternative to Gravatar
- Uses libravatar.org federated service
- 13x13 pixel avatars with retro fallback style
- MD5-based avatar lookup
