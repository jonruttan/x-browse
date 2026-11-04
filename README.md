# x-browse

A terminal browser on x-lang, in the vein of lynx, links and w3m, as a
lang bundle.  It browses Markdown and HTML: headings, bold, italic,
code, quotes, lists, links and forms drawn with the terminal's
attributes, in tabs.

    x -l browse -- [LOCATION ...]
    x -l browse -- -dump [-width N] LOCATION

A location is a path, an `http://` or `https://` url, or `about:help`.
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

## -dump

`-dump` writes the document as text on standard output, laid out `-width`
columns wide (80 when not given), as lynx's `-dump` does: each link's text
led by its number in brackets, a form's fields drawn as the browser draws
them, and after the document the list of where the links go.

## Requirements

x-lang v0.44.0: `x/codec/markdown`, `x/codec/html` with forms, and `x/tui`
with fields, and `Term key` naming Page Up and Page Down.

## Tests

    make test X=/path/to/x
    make check X=/path/to/x

## Not yet

Images other than their text, and files sent from a form.
