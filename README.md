# x-browse

A terminal browser on x-lang, in the vein of lynx, links and w3m, as a
lang bundle.  It browses Markdown and HTML: headings, bold, italic,
code, quotes, lists, links and forms drawn with the terminal's
attributes, in tabs, and PNG images in half-block characters.

    x -l browse -- [LOCATION ...]
    x -l browse -- -d [-w N] LOCATION

A location is a path, an `http://` or `https://` url, a `data:` url in
base64, or `about:help`.
Each location given opens in a tab of its own; with none, the browser
opens the current directory.  A file ending `.md`, `.markdown` or
`.mdown`, or a response of type `text/markdown`, is read as Markdown; one
ending `.html` or `.htm`, or a response of type `text/html`, as HTML,
shown as the same headings, lists, quotes, code and links, a table as a
line a row; a directory is shown as a list of its entries, linked;
anything else is shown as text.

## Keys

    j Down          a line down            k Up           a line up
    Space f PgDn    a page down            b PgUp         a page up
    d               half a page down       u              half a page up
    g Home          the top                G End          the bottom

    Tab             the next link or field p              the previous one
    Enter Right l   follow the link        t              follow it in a new tab
    Left h BS       back
    o               open a location        O              open one in a new tab
    r               load the document again

    Enter           on a text field, type its text; on a checkbox or a radio
                    button, turn it on or off; on a select, its next option;
                    on a button, send the form (t sends it to a new tab)

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

A form's fields are drawn as lynx draws them: a text field as its text
padded with underscores, a checkbox as `[ ]` or `[X]`, a radio button as
`( )` or `(*)`, a select as its chosen option in brackets, a button as
its label in brackets.  They are selected as links are, and the bottom
line says what the selected one is.  `Enter` on a button sends the form:
by GET it opens the action with the fields as the query, by POST it
sends them as the body, `application/x-www-form-urlencoded`.  What is
typed into a form stays with the document in its tab, so going back
finds it as it was left.

## --dump

`-d`, `--dump`, writes the document as text on standard output, laid out
`-w N`, `--width N`, columns wide (80 when not given), as lynx's `-dump` does: each link's text
led by its number in brackets, a form's fields drawn as the browser draws
them, and after the document the list of where the links go.  A PNG
image is written as its picture in half blocks and 24-bit colour, no
wider than the columns.

## Images

An image in a page is its alternative text in brackets, a link to the
image.  Enter on it shows the image fitted to the window, two pixels a
character cell in half blocks; the back keys return.  `i` shows a page's
images inline, each below its brackets, fitted to the page's width and a
row short of the window, and `i` again puts them back to links; it holds
for every tab.  An image is loaded once a location while the browser
runs, and one that does not load, or is not a PNG, stays a link.  A
location whose
bytes are a PNG opens as an image, whatever its name or type.  Colours
are 24-bit when `COLORTERM` is `truecolor` or `24bit`, else the nearest
of the 256-colour palette.

## Requirements

x-lang v0.47.0: `x/codec/markdown`, `x/codec/html` with forms, `x/codec/png`,
and `x/tui` with fields and pictures, and `Term key` naming Page Up and
Page Down.

## Tests

    make test X=/path/to/x
    make check X=/path/to/x

## Not yet

Images other than PNG, `data:` urls not in base64, and files sent from
a form.
