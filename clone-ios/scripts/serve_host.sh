#!/bin/sh
# Serve the UTF-8 keyboard host for the iOS UI test / manual Safari check.
cd "$(dirname "$0")/host"
exec python3 -m http.server 8899 --bind 127.0.0.1
