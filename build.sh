#!/bin/bash

rm -rf publish
mkdir -p publish/blog
cd md
find . -type f -name '*.md' -exec sh -c 'mmark -t ../layout.mustache -i {} -o ../publish/$(basename {} .md).html' \;
cd ..
npx tailwindcss -i main.css -o publish/main.min.css --minify
git checkout gh-pages && mv publish/* . && git add . && git commit -m "automatic update" && git checkout main
