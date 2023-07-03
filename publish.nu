git checkout gh-pages
cp -r build/* .
git add .
git commit -m "auto-publish"
git checkout main
