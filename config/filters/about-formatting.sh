#!/bin/sh
# cgit about-filter for formatting README files
# Converts markdown, reStructuredText, HTML, and plain text to HTML

# Get filename from argument (cgit passes it as $1)
FILENAME="$1"

# Read content from stdin
CONTENT=$(cat)

# Check file extension and convert accordingly
case "$FILENAME" in
    *.md|*.markdown)
        # Convert Markdown to HTML using markdown library with extensions
        echo "$CONTENT" | python3 -c "import sys, markdown; print(markdown.markdown(sys.stdin.read(), extensions=['markdown.extensions.fenced_code', 'markdown.extensions.tables', 'markdown.extensions.codehilite']))" 2>/dev/null || echo "$CONTENT"
        ;;
    *.rst)
        # Convert reStructuredText to HTML
        echo "$CONTENT" | rst2html 2>/dev/null | sed -e '1,/<body>/d' -e '/<\/body>/,$d' || echo "$CONTENT"
        ;;
    *.html)
        # HTML files - pass through as-is
        echo "$CONTENT"
        ;;
    *)
        # Plain text files - escape HTML and wrap in <pre>
        echo "$CONTENT" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' | \
        awk 'BEGIN { print "<pre>" } { print } END { print "</pre>" }'
        ;;
esac
