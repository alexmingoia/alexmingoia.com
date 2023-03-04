#!/bin/sh
set -eu
IFS='	'

# Create tab separated file with filename, title, creation date, last update
index_tsv() {
	for f in "$1"/*.md
	do
		title=$(sed -n '/^# /{s/# //p; q;}' "$f")
		printf '%s\t%s\t%s\t%s\n' "$f" "${title:="No Title"}"
	done
}

index_html() {
	# Print header
	title=$(sed -n '/^# /{s/# //p; q;}' index.md)
	sed "s/{{title}}/$title/" templates/page.header.html

	# Intro text
	mmark -i index.md

	# Posts
	echo "<ul>"
	while read -r f title created; do
		link=$(echo "$f" | sed -E 's|.*/(.*).md|\1/|')
		created=$(echo $(head -3 "$f" | tail -1))
	 	echo "<li>$created &mdash; <a href=\"$link\">$title</a></li>"
	done < "$1" | sort -r
	echo "</ul>"

	# Print footer after post list
	cat templates/page.footer.html
}

atom_xml() {
	uri=$(sed -rn '/atom.xml/ s/.*href="([^"]*)".*/\1/ p;' templates/page.header.html)
	domain=$(echo "$uri" | sed 's/atom.xml//g' | sed 's|/[^/]*$||')
	first_commit_date=$(git log --pretty='format:%ai' . | cut -d ' ' -f1 | tail -1)

	cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
	<title>$(sed -n '/^# /{s/# //p; q;}' index.md)</title>
	<link href="$domain/atom.xml" rel="self" />
	<updated>$(date +%FT%TZ)</updated>
	<author>
		<name>$(git config user.name)</name>
	</author>
	<id>$domain,$first_commit_date:default-atom-feed/</id>
EOF

	while read -r f title created; do

		content=$(mmark -i "$f" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
		post_link=$(echo "$f" | sed -E 's|posts/(.*).md|\1|')
		basic_date=$(echo $(head -3 "$f" | tail -1))
		published_date=$(date -j -f "%Y-%m-%d" +%FT%TZ $basic_date)

		cat <<EOF
	<entry>
		<title>$title</title>
		<content type="html">$content</content>
		<link href="$domain/$post_link"/>
		<id>$domain/$post_link</id>
		<updated>$published_date</updated>
		<published>$published_date</published>
	</entry>
EOF
	done < "$1"

	echo '</feed>'
}

write_page() {
	filename=$1
	directory=$(echo $(basename "$filename" .md))
	$(mkdir -p build/$directory)
	target=$(echo "$filename" | sed -r 's|(posts\|pages)/(.*).md|build/\2/index.html|')
	created=$(echo $(head -3 "$filename" | tail -1))
	title=$2

	sed "s/{{title}}/$title/" templates/$4.header.html >> "$target"

	head -1 "$filename" | mmark >> "$target"
	tail +4 "$filename" | mmark >> "$target"

	sed "s/{{date}}/$created/g" templates/$4.footer.html >> "$target"
}

rm -fr build && mkdir build

# Blog posts
index_tsv posts | sort -rt "	" -k 3 > build/posts.tsv
index_html build/posts.tsv > build/index.html
atom_xml build/posts.tsv > build/atom.xml
while read -r f title created; do
	write_page "$f" "$title" "$created" "post"
done < build/posts.tsv

cp main.css build/main.css
