# prepare directory for build
rm -rf build/
mkdir build

# copy assets
cp -r images build/images

# write pages
cp -r pages/*.html build/
glob pages/*.md
  | each { |it| open $it | mmark -t 'templates/page.html' | save $'build/($it | path basename | str replace ".md" "").html' }

# annotate blog entry markdown with title and date
let entries = (
  glob blog/*.md
    | wrap filename
    | insert name { |it| $it.filename | path basename | str replace '.md$' '' }
    | insert md { |it| open $it.filename --raw | decode utf-8 | str replace '# ([^\n]+)' $"# [$1]\(/($it.name)\)" }
    | insert title { |it| $it.md | parse --regex "title: ([^\n]+)" | get capture0 | append "" | first }
    | insert date { |it| $it.md | parse --regex 'date: ([\d-]+)' | get capture0 | append "" | first }
    | sort-by date --reverse
)

# write blog pages
$entries | each { |it| $it.md | mmark -t 'templates/entry.html' | save $'build/($it.name).html' }

# concatenate entries and write index page
let index_entries_html = (
  $entries
    | each { |it| ["<article>", ($it.md | str replace "# " "## " | mmark), "</article>"] | str join "" }
    | str join "<hr />"
)
open 'templates/index.html' | str replace '{{& output}}' $index_entries_html | save 'build/index.html'

# write RSS/Atom feed
let index_entries_atom = (
  $entries
    | each { |it| open 'templates/entry.xml' --raw | decode 'utf-8' | str replace '{{title}}' $it.title | str replace '{{updated}}' $it.date | str replace --all '{{permalink}}' $'https://www.alexmingoia.com/($it.name)' | str replace '{{& content}}' ($it.md | mmark | escape-html) }
    | str join ""
)
open 'templates/feed.xml' --raw | decode utf-8 | str replace '{{updated}}' (date now | date format "%Y-%m-%d %H:%M:%S%z") | str replace '{{& entries}}' $index_entries_atom | save 'build/feed.xml'

# HTML content must be escaped in Atom+XML
def escape-html [] {
  str replace --all '&' '&amp;' | str replace --all '<' '&lt;' | str replace --all '>' '&gt;' | str replace --all '"' '&quot;' | str replace --all "'" '&#39;'
}
