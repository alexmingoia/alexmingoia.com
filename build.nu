### Alex's nushell static blog generator
#
# All markdown files with `published: YYYY-MM-DD` metadata are used as blog entries
# 
# $config and $blog_entries fields are available as template {{variables}}

let config = {
  build_path: 'build',
  markdown_path: '/Users/alex/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes/blog',
  assets_path: 'assets',
  templates_path: 'templates',
  blog_title: 'Alex Mingoia',
  blog_description: 'Writing, notes, and projects by Alex Mingoia.',
  blog_icon: 'https://www.alexmingoia.com/images/alex.jpeg',
  blog_author: 'Alex Mingoia',
  blog_www_url: 'https://www.alexmingoia.com/',
  blog_xml_url: 'https://www.alexmingoia.com/feed.xml',
}

alias markdown = mmark

# Prepare directory for build
rm -rf $config.build_path
mkdir $config.build_path

# Copy assets to build folder
glob $'($config.assets_path)/*' | each { |it| cp $it $'($config.build_path)/($it | path basename)' }

# Compile blog entries (table fields are available as template {{variables}})
let blog_entries = (
  glob $'($config.markdown_path)/**/*.md'
    | wrap filename
    | insert md { |it| open $it.filename }
    | insert published { |it| try { $it.md | parse -r 'published: (\d{4}-\d\d-\d\d(T\d\d:\d\d)?)' | values | flatten | first | date format %+ } catch { "" } }
    | insert updated { |it| $it.md | try { parse -r 'updated: (\d{4}-\d\d-\d\d(T\d\d:\d\d)?)' | values | flatten | first | date format %+ } catch { $it.published } }
    | where { |it| not ($it.published | is-empty) }
    | insert published_fmt { |it| $it.published | date format "%e %b %Y" }
    | insert updated_fmt { |it| $it.updated | date format "%e %b %Y" }
    | insert kind { |it| if ($it.md | parse -r '# (.+)\n' | values | flatten | length) > 0 { "article" } else { "note" } }
    | insert url { |it| $it.filename | path basename | str replace ".md" "" | str kebab-case }
    | insert permalink { |it| $'($config.blog_www_url)($it.url)' }
    | insert summary { |it| $it.md | split row "---\n\n" | last | str replace '# .+\n+' '' | lines | first | truncate 24 | escape-html }
    | insert title { |it| try { $it.md | parse -r '# (.+)\n' | values | flatten | first } catch { $it.summary | truncate 6 } }
    | insert html { |it| $it.md | split row "---\n\n" | last | str replace "# .+\n+" '' | markdown }
    | each { |it| $it | merge $config }
    | sort-by published
    | enumerate
    | each { |it| $it.item | insert index $it.index }
)

# Write blog entry.(article|note).html pages ({{next}} and {{prev}} template variables are HTML links or empty strings)
$blog_entries
  | insert prev { |it| try { ['Previous: ', '<a href="', ($blog_entries | get ($it.index - 1) | get url), '.html">', ($blog_entries | get ($it.index - 1) | get title), '</a>'] | str join "" } catch { "" } }
  | insert next { |it| try { ['Next: ', '<a href="', ($blog_entries | get ($it.index + 1) | get url), '.html">', ($blog_entries | get ($it.index + 1) | get title), '</a>'] | str join "" } catch { "" } }
  | each { |it| $it.html | render $'entry.($it.kind).html' $it | render 'layout.html' ({page_title: $'($it.title) | ($config.blog_title)', page_description: $it.summary} | merge $it) | save $'($config.build_path)/($it.url).html' }

# Write index.html page with concatenated blog entries
$blog_entries
  | reverse
  | each { |it| $it.html | render $'entry.($it.kind).html' $it }
  | str join ""
  | render 'index.html' $config
  | render 'layout.html' ($config | merge {page_title: $config.blog_title, page_description: $config.blog_description})
  | save $'($config.build_path)/index.html'

$blog_entries
  | each { |it| $it.html | escape-html | render 'entry.xml' $it }
  | str join ""
  | render 'index.xml' ($config | insert updated (try { $blog_entries | last | get updated } catch { date now | date format %+ }))
  | save $'($config.build_path)/feed.xml'

# Render HTML template, replacing {{content}} with pipe contents and {{key}} with associated record value
#
# Also supports non-recursive {{> includes.html}}
def render [partial, vars] {
  let content = $in
  let tpl = (open $'($config.templates_path)/($partial)' --raw | decode utf-8 | str replace '{{content}}' $content)
  let tpl_includes = ($tpl | parse --regex '{{> ([\w.]+)}}').capture0
  let tpl_expanded = ($tpl_includes | reduce -f $tpl { |it, acc| $acc | str replace $"{{> ($it)}}" (open $'($config.templates_path)/($it)') })
  let tpl_vars = ($tpl_expanded | parse --regex '{{(\w+)}}').capture0
  $tpl_vars | reduce -f $tpl_expanded { |it, acc| try { $acc | str replace $"{{($it)}}" ($vars | get $it) } catch { $acc | str replace $'{{($it)}}' '' } } 
}

# HTML content must be escaped in Atom+XML
def escape-html [] {
  str replace --all '&' '&amp;' | str replace --all '<' '&lt;' | str replace --all '>' '&gt;' | str replace --all '"' '&quot;' | str replace --all "'" '&#39;'
}

def truncate [len] {
  str trim | split row " " | take $len | append "..." | str join " "
}
