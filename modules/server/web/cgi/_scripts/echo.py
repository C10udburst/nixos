#!/usr/bin/env python3
import os
import sys

# Required CGI response header to output raw text to the client
print("Content-Type: text/plain\r\n\r\n", end="")

# 1. RECONSTRUCT THE REQUEST LINE
# SERVER_PROTOCOL provides the version (e.g., HTTP/1.1)
# REQUEST_URI provides the full path and query string
method = os.environ.get('REQUEST_METHOD', 'GET')
uri = os.environ.get('REQUEST_URI', os.environ.get('SCRIPT_NAME', '/'))
protocol = os.environ.get('SERVER_PROTOCOL', 'HTTP/1.1')

print(f"{method} {uri} {protocol}")

# 2. RECONSTRUCT HEADERS
# Standard headers are prefixed with HTTP_, converted to uppercase, and use underscores
# Special case: CONTENT_TYPE and CONTENT_LENGTH often lack the HTTP_ prefix
headers = {}

for key, value in os.environ.items():
    if key.startswith('HTTP_'):
        # Convert HTTP_USER_AGENT -> User-Agent
        header_name = key[5:].replace('_', '-').title()
        headers[header_name] = value
    elif key in ('CONTENT_TYPE', 'CONTENT_LENGTH'):
        header_name = key.replace('_', '-').title()
        headers[header_name] = value

# Print reconstructed headers in standard format
for name, val in headers.items():
    print(f"{name}: {val}")

# 3. SEPARATOR
# HTTP requires a blank line between headers and body
print("")

# 4. RECONSTRUCT THE BODY
# The body is read from stdin based on CONTENT_LENGTH
try:
    content_length = int(os.environ.get('CONTENT_LENGTH', 0))
except (ValueError, TypeError):
    content_length = 0

if content_length > 0:
    # Use sys.stdin.buffer to read binary data correctly if needed
    body = sys.stdin.buffer.read(content_length)
    sys.stdout.buffer.write(body)
