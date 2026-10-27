# x-browse

A terminal browser on x-lang, in the vein of lynx, links and w3m, as a
lang bundle.  It browses Markdown: headings, bold, italic, code, quotes,
lists and links drawn with the terminal's attributes, in tabs.

    x -l browse -- [LOCATION ...]
    x -l browse -- -dump [-width N] LOCATION

A location is a path, an `http://` or `https://` url, or `about:help`.
Each location given opens in a tab of its own; with none, the browser
opens the current directory.  A file ending `.md`, `.markdown` or
`.mdown`, or a response of type `text/markdown`, is read as Markdown; a
directory is shown as a list of its entries, linked; anything else is
shown as text.

## Keys

    j Down          a line down            k Up           a line up
    Space f PgDn    a page down            b PgUp         a page up
    d               half a page down       u              half a page up
    g Home          the top                G End          the bottom

    Tab             the next link          p              the previous link
    Enter Right l   follow the link        t              follow it in a new tab
    Left h BS       back
    o               open a location        O              open one in a new tab
    r               load the document again

    / Ctrl-S        search for text        n              the next match
                                           N              the previous match

    ] >             the next tab           [ <            the previous tab
    1-9             that tab               x              close this tab

    ?               the keys, in a new tab
    Ctrl-L          draw the screen again
    q Ctrl-C        quit

The bar at the top lists the tabs, the current one bold.  The bottom
line shows where the selected link goes, or with none selected where the
document is, and on the right the lines shown and how many there are.

A link is resolved against the document it is in, as a browser
resolves a relative url.  A link's `#fragment` goes to the heading whose
GitHub slug it is.  Each tab keeps the documents it came from; going
back shows one where it was left, the same link selected.

A search is for text in any case, from the top line shown: the line it
is found on goes to the top.  `n` looks on from the last match while it
is on the screen, otherwise from the top line; `N` looks back the same
way.  `/` with nothing typed searches for the last text again.

## -dump

`-dump` writes the document as text on standard output, laid out `-width`
columns wide (80 when not given), as lynx's `-dump` does: each link's text
led by its number in brackets, and after the document the list of where
the links go.

## Requirements

x-lang with `x/codec/markdown` and `x/tui` (x-lang#1101 and #1103).

## Tests

    make test X=/path/to/x
    make check X=/path/to/x

## Not yet

Forms, HTML, and images other than their text.
