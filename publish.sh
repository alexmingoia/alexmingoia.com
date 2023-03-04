#!/bin/bash

./build.sh
git checkout gh-pages && mv build/* . && git add . && git commit -m "automatic update" && git checkout main
