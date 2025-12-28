#!/usr/bin/env python3
"""
cgit email filter using Libravatar
This filter converts email addresses to Libravatar avatar URLs
"""

import sys
import hashlib
import os

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    
    # Get email from command line argument (includes < and >)
    email = sys.argv[1]
    
    # Strip < and > and convert to lowercase
    email_clean = email.strip('<>').lower()
    
    # Generate MD5 hash
    md5_hash = hashlib.md5(email_clean.encode('utf-8')).hexdigest()
    
    # Read the email content from stdin
    content = sys.stdin.read()
    
    # Use HTTPS if available, otherwise HTTP
    if os.getenv('HTTPS'):
        baseurl = "https://seccdn.libravatar.org/"
    else:
        baseurl = "http://cdn.libravatar.org/"
    
    # Output avatar image followed by the email content
    avatar_url = f"{baseurl}avatar/{md5_hash}?s=13&amp;d=retro"
    print(f"<img src='{avatar_url}' width='13' height='13' alt='Libravatar' /> {content}", end='')

if __name__ == '__main__':
    main()
