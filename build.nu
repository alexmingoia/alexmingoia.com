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
    | insert content { |it| $it.md | split row "---\n\n" | last | str replace "# .+\n+" '' }
    | insert kind { |it| if ($it.md | parse -r '# (.+)\n' | values | flatten | length) > 0 { "article" } else { "note" } }
    | insert date { |it| $it.metadata.date }
    | insert tags { |it| try { $it.metadata.tags | split row -r ', ?' } catch { [] } }
    | sort-by date
    | enumerate
    | each { |it| $it.item | insert index $it.index }
)

# write pages
$pages | each { |it| $it.md | str replace '# (.+)' '' | markdown | render 'page.html' $it.metadata | render 'layout.html' {title: $'($it.metadata.title) | ($site_title)'} | save $'build/($it.url).html' }

# write blog entries
$blog_entries
  | insert prev { |it| try { ['Previous: ', '<a href="', ($blog_entries | get ($it.index - 1) | get url), '.html">', ($blog_entries | get ($it.index - 1) | get metadata | get title), '</a>'] | str join "" } catch { "" } }
  | insert next { |it| try { ['Next: ', '<a href="', ($blog_entries | get ($it.index + 1) | get url), '.html">', ($blog_entries | get ($it.index + 1) | get metadata | get title), '</a>'] | str join "" } catch { "" } }
  | each { |it| $it.content | markdown | render $'entry.($it.kind).html' ($it.metadata | upsert date { |metadata| $metadata.date | date format "%e %b %Y" } | insert next $it.next | insert prev $it.prev) | render 'layout.html' {title: $'($it.metadata.title) ($site_title)'} | save $'build/($it.url).html' }

# concatenate entries and write index page
let blog_entries_list_html = (
  $blog_entries
    | reverse
    | where { |it| try { $it.metadata.index != "false" } catch { true } }
    | each { |it| $it.content | markdown | render $'index.($it.kind).html' ($it.metadata | upsert url $'/($it.url)' | upsert date { |metadata| $metadata.date | date format "%e %b %Y" }) }
    | str join ""
)

$blog_entries_list_html
  | render 'index.html' {}
  | render 'layout.html' {title: $site_title}
  | save 'build/index.html'

# write RSS/Atom feed to build/feed.xml
let index_entries_atom = (
  $blog_entries
    | where { |it| try { $it.metadata.index != "false" } catch { true } }
    | each { |it| $it.md | markdown | escape-html | render 'entry.xml' ($it.metadata | upsert updated $it.metadata.date | upsert permalink $'($site_url)/($it.url)') }
    | str join ""
)
$index_entries_atom | render 'index.xml' {updated: (date now | date format "%Y-%m-%d %H:%M:%S%z")} | save 'build/feed.xml'

# return record of markdown metadata
def extract_metadata [] {
  let md = $in
  let content = ($md | split row "---\n")
  let h1 = ($md | parse -r '# (.+)\n' | values | flatten)
  let title = (if ($h1 | length) > 0 { $h1 | first | escape-html } else { $md | split row "---\n\n" | last | lines | first | truncate | escape-html })
  if ($content | length) > 1 {
    let metadata = ($content | drop nth 0 | first | lines | each { |it| $it | split column ': ' } | flatten | transpose -r | into record)
    $metadata | upsert title $title
  } else {
    {title: $title}
  }
}

# render HTML template, replacing {{var}} with vars record value
def render [partial, vars] {
  let content = $in
  let tpl = (open $'templates/($partial)' --raw | decode utf-8 | str replace '{{content}}' $content)
  let tpl_includes = ($tpl | parse --regex '{{> ([\w.]+)}}').capture0
  let tpl_expanded = ($tpl_includes | reduce -f $tpl { |it, acc| $acc | str replace $"{{> ($it)}}" (open $'templates/($it)') })
  let tpl_vars = ($tpl_expanded | parse --regex '{{(\w+)}}').capture0
  $tpl_vars | reduce -f $tpl_expanded { |it, acc| try { $acc | str replace $"{{($it)}}" ($vars | get $it) } catch { $acc | str replace '${{($it)}}' '' } } 
}

# HTML content must be escaped in Atom+XML
def escape-html [] {
  str replace --all '&' '&amp;' | str replace --all '<' '&lt;' | str replace --all '>' '&gt;' | str replace --all '"' '&quot;' | str replace --all "'" '&#39;'
}

def truncate [] {
  str trim | split row " " | take 6 | append "..." | str join " "
}
