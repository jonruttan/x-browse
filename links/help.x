; # x-links -- a terminal browser on x-lang
;
; ## links/help.x -- about:help, the keys
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)

(module links/help)

(def links-help
  (Str8 join "\n"
    (list
      "# x-links"
      ""
      "A Markdown browser.  The bar at the top lists the tabs; the line at the"
      "bottom shows the selected link, or where this document is."
      ""
      "## Moving"
      ""
      "- `j` `Down`: a line down; `k` `Up`: a line up"
      "- `Space` `f` `PgDn`: a page down; `b` `PgUp`: a page up"
      "- `d`: half a page down; `u`: half a page up"
      "- `g` `Home`: the top; `G` `End`: the bottom"
      ""
      "## Links"
      ""
      "- `Tab` `n`: the next link; `p` `N`: the previous one"
      "- `Enter` `Right` `l`: follow the selected link"
      "- `t`: follow it in a new tab"
      "- `Left` `h` `Backspace`: back"
      "- `o`: open a location; `O`: open one in a new tab"
      "- `r`: load this document again"
      ""
      "## Tabs"
      ""
      "- `]` `>`: the next tab; `[` `<`: the previous one"
      "- `1` to `9`: that tab"
      "- `x`: close this tab"
      ""
      "## The rest"
      ""
      "- `?`: this page, in a new tab"
      "- `Ctrl-L`: draw the screen again"
      "- `q` `Ctrl-C`: quit"
      ""
      "A location is a path, an `http://` or `https://` url, or `about:help`."
      "")))

(provide links/help links-help)
