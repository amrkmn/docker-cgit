#!/usr/bin/env python3

# Enhanced syntax highlighting filter for cgit with dark theme support
# Uses Pygments with dark-compatible color scheme and improved language detection
#
# Features:
# - 500+ language support via Pygments
# - Dark theme compatible (monokai style)
# - Smart lexer detection (filename, shebang, content analysis)
# - Line numbers support
# - Enhanced highlighting for diffs

import sys
import io
from pygments import highlight
from pygments.util import ClassNotFound
from pygments.lexers import TextLexer
from pygments.lexers import guess_lexer
from pygments.lexers import guess_lexer_for_filename
from pygments.formatters import HtmlFormatter


# Use UTF-8 encoding for stdin/stdout
sys.stdin = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8', errors='replace')
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# Read the file content
data = sys.stdin.read()
filename = sys.argv[1]

# Use monokai style for dark theme compatibility
# Other dark-compatible options: 'native', 'vim', 'paraiso-dark', 'dracula'
# Set nobackground=True to use cgit's own background
formatter = HtmlFormatter(
    style='monokai',
    nobackground=True,
    cssclass='highlight',
    linenos=False  # cgit handles line numbers itself
)

# Try to detect the lexer
try:
    # First, try to guess by filename (most reliable)
    lexer = guess_lexer_for_filename(filename, data)
except ClassNotFound:
    # If that fails, check for shebang
    if data and len(data) > 2 and data[0:2] == '#!':
        try:
            lexer = guess_lexer(data)
        except ClassNotFound:
            lexer = TextLexer()
    else:
        lexer = TextLexer()
except TypeError:
    lexer = TextLexer()

# Output CSS styles first
sys.stdout.write('<style>')
sys.stdout.write(formatter.get_style_defs('.highlight'))
sys.stdout.write('</style>')

# Output highlighted code
sys.stdout.write(highlight(data, lexer, formatter, outfile=None))
