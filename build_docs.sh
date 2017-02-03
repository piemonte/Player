#!/bin/bash

# Docs by jazzy
# https://github.com/realm/jazzy
# ------------------------------

jazzy \
	--clean \
	--author 'Patrick Piemonte' \
    --author_url 'https://patrickpiemonte.com' \
    --github_url 'https://github.com/piemonte/Player' \
    --sdk iphonesimulator \
    --xcodebuild-arguments -scheme,'Player' \
    --module 'Player' \
    --framework-root . \
    --readme README.md \
    --output docs/
