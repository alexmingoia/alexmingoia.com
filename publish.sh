#!/bin/bash

./build.sh
git checkout gh-pages
cp -rf build/* . 
git add .
git commit -m "automatic update"
git checkout main
