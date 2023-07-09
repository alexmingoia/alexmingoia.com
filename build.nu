let site_title = 'Alex Mingoia'

# prepare directory for build
rm -rf build/
mkdir build

# copy images
cp -r images build/images

# write pages
glob pages/*.md
  | wrap filename
  | insert md { |it| open $it.filename --raw | decode utf-8 }
  | insert name { |it| $it.filename | path basename | str replace ".md" "" }
  | insert page_title { |it| $'($it.name | str capitalize | str replace --all "-" " ") | ($site_title)' }
  | insert title { |it| $it.md | parse --regex '# ([^\n]+)' | get capture0 | append "" | first }
  | update md { |it| $it.md | str replace '# ([^\n]+)\n\n([\d-]+\n\n)?' "" }
  | each { |it| $it.md | mmark | render_html 'page' {title: $it.title} | render_html 'layout' {title: $it.page_title} | save $'build/($it.name).html' }

# annotate blog entry markdown with title and date
let entries = (
  glob blog/*.md
    | wrap filename
    | insert name { |it| $it.filename | path basename | str replace '.md$' '' }
    | insert md { |it| open $it.filename --raw | decode utf-8 }
    | insert title { |it| $it.md | parse --regex '# ([^\n]+)' | get capture0 | append "" | first }
    | insert date { |it| $it.md | parse --regex '\n\n([\d-]+)\n\n' | get capture0 | append "" | first }
    | update md { |it| $it.md | str replace '# ([^\n]+)\n\n([\d-]+\n\n)?' "" }
    | sort-by date --reverse
)

# write blog pages
$entries | each { |it| $it.md | mmark | render_html 'entry' {title: $it.title, date: ($it.date | date format "%e %b %Y")} | render_html 'layout' {title: $'($it.title) | ($site_title)'} | save $'build/($it.name).html' }

# concatenate entries and write index page
$entries
  | each { |it| $it.md | mmark | render_html 'index.entry' {title: $it.title, date: ($it.date | date format "%e %b %Y"), url: $'/($it.name)'} }
  | str join "<hr />"
  | render_html 'index'
  | render_html 'layout' {title: $site_title}
  | save 'build/index.html'

# write RSS/Atom feed to build/feed.xml
let index_entries_atom = (
  $entries
    | each { |it| open 'templates/entry.xml' --raw | decode 'utf-8' | str replace '{{title}}' $it.title | str replace '{{updated}}' $it.date | str replace --all '{{permalink}}' $'https://www.alexmingoia.com/($it.name)' | str replace '{{content}}' ($it.md | mmark | escape-html) }
    | str join ""
)
open 'templates/index.xml' --raw | decode utf-8 | str replace '{{updated}}' (date now | date format "%Y-%m-%d %H:%M:%S%z") | str replace '{{content}}' $index_entries_atom | save 'build/feed.xml'

# HTML content must be escaped in Atom+XML
def escape-html [] {
  str replace --all '&' '&amp;' | str replace --all '<' '&lt;' | str replace --all '>' '&gt;' | str replace --all '"' '&quot;' | str replace --all "'" '&#39;'
}

def render_html [partial, vars = {}] {
  let content = $in
  let tpl_html = (open $'templates/($partial).html' | str replace '{{content}}' $content)
  let tpl_vars = ($tpl_html | parse --regex '{{(\w+)}}').capture0
  $tpl_vars | reduce -f $tpl_html { |it, acc| try { $acc | str replace $'{{($it)}}' ($vars | get $it | escape-html) } catch { $acc | str replace '${{($it)}}' '' } } 
}
