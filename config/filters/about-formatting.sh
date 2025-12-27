#!/bin/sh
# cgit about-filter for formatting README files
# Converts markdown, reStructuredText, HTML, and plain text to HTML

FILE="$1"

# Check file extension and convert accordingly
case "$FILE" in
    *.md|*.markdown)
        # Convert Markdown to HTML using markdown library
        cat "$FILE" | python3 -m markdown 2>/dev/null || cat "$FILE"
        ;;
    *.rst)
        # Convert reStructuredText to HTML
        rst2html "$FILE" 2>/dev/null | sed -e '1,/<body>/d' -e '/<\/body>/,$d' || cat "$FILE"
        ;;
    *.html)
        # HTML files - pass through as-is
        cat "$FILE"
        ;;
    *)
        # Plain text files - escape HTML and wrap in <pre>
        sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' "$FILE" | \
        awk 'BEGIN { print "<pre>" } { print } END { print "</pre>" }'
        ;;
esac
