#!/bin/bash

mkdir -p publish
rm -rf publish/*
find . -maxdepth 1 -type f -name '*.md' -exec sh -c 'mmark -t layout.html.mustache -i {} -o publish/$(basename {} .md).html' \;

find . -maxdepth 1 -type f -name '*.md' -exec sh -c 'mmark -t layout.atom.mustache -i {} -o publish/$(basename {} .md).xml' \;
rm publish/index.xml
cat layout.atom.header > publish/atom
echo "<updated>$(date -u +"%Y-%m-%dT%H:%M:%SZ")</updated>" >> publish/atom
cat publish/*.xml >> publish/atom
cat layout.atom.footer >> publish/atom
rm publish/*.xml
mv publish/atom publish/atom.xml

npx tailwindcss -i main.css -o publish/main.min.css --minify
