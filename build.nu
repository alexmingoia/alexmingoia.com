let site_title = 'Alex Mingoia'
let site_url = 'https://www.alexmingoia.com'

alias markdown = mmark

# prepare directory for build
rm -rf build/
mkdir build

# copy images
cp -r images build/images

# compile pages table
let pages = (
  glob pages/*.md
    | wrap filename
    | insert url { |it| $it.filename | path basename | str replace ".md" "" }
    | insert md { |it| open $it.filename }
    | insert metadata { |it| $it.md | extract_metadata }
)

# compile blog entries table
let blog_entries = (
  glob blog/*.md
    | wrap filename
    | insert url { |it| $it.filename | path basename | str replace ".md" "" }
    | insert md { |it| open $it.filename }
    | insert metadata { |it| $it.md | extract_metadata }
    | insert date { |it| $it.metadata.date }
    | insert tags { |it| try { $it.metadata | get tags | split row -r ', ?' } catch { [] } }
    | sort-by date --reverse
)

# write pages
$pages | each { |it| $it.md | str replace '# (.+)' '' | markdown | render 'page.html' $it.metadata | render 'layout.html' {title: $'($it.metadata.title) | ($site_title)'} | save $'build/($it.url).html' }

# write blog entries
$blog_entries | each { |it| $it.md | str replace '# (.+)' '' | markdown | render 'entry.html' ($it.metadata | upsert date { |metadata| $metadata.date | date format "%e %b %Y" }) | render 'layout.html' {title: $'($it.metadata.title) | ($site_title)'} | save $'build/($it.url).html' }

# concatenate entries and write index page
let blog_entries_list_html = (
  $blog_entries
    | each { |it| $it.md | str replace '# (.+)' '' | markdown | render 'index.entry.html' ($it.metadata | upsert url $'/($it.url)') }
    | str join ""
)

let latest_entry_html = (
  $blog_entries
    | take 1
    | each { |it| $it.md | split row "---\n\n" | last | str replace "# .+\n\n" '' | lines | first | render 'index.latest.html' ($it.metadata | upsert url $'/($it.url)' | upsert date { |metadata| $metadata.date | date format "%e %b %Y" } ) }
    | first
) 

$blog_entries_list_html
  | render 'index.html' {latest: $latest_entry_html}
  | render 'layout.html' {title: $site_title}
  | save 'build/index.html'

# write RSS/Atom feed to build/feed.xml
let index_entries_atom = (
  $blog_entries
    | each { |it| $it.md | markdown | escape-html | render 'entry.xml' ($it.metadata | upsert updated $it.metadata.date | upsert permalink $'($site_url)/($it.url)') }
    | str join ""
)
$index_entries_atom | render 'index.xml' {updated: (date now | date format "%Y-%m-%d %H:%M:%S%z")} | save 'build/feed.xml'

# return record of markdown metadata
def extract_metadata [] {
  let content = ($in | split row "---\n")
  if ($content | length) > 1 {
    $content | drop nth 0 | first | lines | each { |it| $it | split column ': ' } | flatten | transpose -r | into record
  } else {
    { title: ($content | parse -r '# (.+)' | values | flatten | first | escape-html) }
  }
}

# render HTML template, replacing {{var}} with vars record value
def render [partial, vars] {
  let content = $in
  let tpl = (open $'templates/($partial)' --raw | decode utf-8 | str replace '{{content}}' $content)
  let tpl_vars = ($tpl | parse --regex '{{(\w+)}}').capture0
  $tpl_vars | reduce -f $tpl { |it, acc| try { $acc | str replace $"{{($it)}}" ($vars | get $it) } catch { $acc | str replace '${{($it)}}' '' } } 
}

# HTML content must be escaped in Atom+XML
def escape-html [] {
  str replace --all '&' '&amp;' | str replace --all '<' '&lt;' | str replace --all '>' '&gt;' | str replace --all '"' '&quot;' | str replace --all "'" '&#39;'
}

