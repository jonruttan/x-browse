# Locations and documents
# @weight 1

browse/doc: where a link goes from the document it is in, the slug a
heading's fragment names, and what loading a location answers.

## resolve

### a path against the document's directory, dots taken out

```browse
(write (list (doc-resolve "docs/a.md" "b.md") (doc-resolve "docs/a.md" "../b.md")
             (doc-resolve "docs/a.md" "./sub/../c.md#x") (doc-resolve "/srv/a.md" "/etc/b.md")
             (doc-resolve "a.md" "../../b.md") (doc-resolve "docs/a.md#top" "#end")
             (doc-resolve "docs/a.md" "") (doc-resolve "docs/" "x/")))
```
---
    ("docs/b.md" "b.md" "docs/c.md#x" "/etc/b.md" "../../b.md" "docs/a.md#end" "docs/a.md" "docs/x/")

### a url against the document's url

```browse
(write (list (doc-resolve "https://h.org/a/b.md" "c.md") (doc-resolve "https://h.org/a/b.md" "/c.md")
             (doc-resolve "https://h.org/a/b.md" "../c.md") (doc-resolve "https://h.org" "c.md")
             (doc-resolve "http://h.org/a/" "//g.org/x") (doc-resolve "a.md" "mailto:me@h.org")
             (doc-scheme? "about:help") (doc-scheme? "c:d") (doc-scheme? "1a:b") (doc-web? "https://x")))
```
---
    ("https://h.org/a/c.md" "https://h.org/c.md" "https://h.org/c.md" "https://h.org/c.md" "http://g.org/x" "mailto:me@h.org" #t #t #f #t)

## slugs

### lower case, spaces to hyphens, punctuation left out

```browse
(write (list (doc-slug "Second part") (doc-slug " Keys & tabs! ") (doc-slug "x-lang_v0.39")))
```
---
    ("second-part" "keys--tabs" "x-lang_v039")

## loading

### a Markdown file, text, a directory, and what is not there

```browse
(write (list (first (doc-load "tests/fixtures/index.md")) (doc-load "tests/fixtures/notes.txt")
             (doc-title "tests/fixtures/index.md" (doc-load "tests/fixtures/index.md"))
             (doc-title "tests/fixtures/notes.txt" (doc-load "tests/fixtures/notes.txt"))
             (doc-load "tests/fixtures/sub")
             (guard (e (e msg)) (doc-load "tests/fixtures/none.md"))
             (guard (e (e msg)) (doc-load "gopher://h"))))
```
---
    ('markdown ('text . "plain text\n\twith a tab\n") "Fixtures" "notes.txt" ('markdown ('heading 1 ("tests/fixtures/sub/")) ('list #f () #t ((('paragraph (('link "../" () ("../"))))) (('paragraph (('link "page.md" () ("page.md")))))))) "no such file" "no way to open this")

### a redirected document's location is where it came from, with the fragment asked for; any other passes through

```browse
(write (list (doc-at "https://h.org/a#top" (pair 'at (pair "https://w.h.org/b" (pair 'text "t"))))
             (doc-at "https://h.org/a#top" (pair 'at (pair "https://w.h.org/b#end" (pair 'text "t"))))
             (doc-at "a.md" (pair 'text "t"))))
```
---
    (("https://w.h.org/b#top" 'text . "t") ("https://w.h.org/b#end" 'text . "t") ("a.md" 'text . "t"))

### a PNG file is an image, its size and RGBA pixels; its title is its name

```browse
(def d (doc-load "tests/fixtures/dot.png"))
(write (list (first d) (List ref 1 d) (List ref 2 d) (Bytes hex (list (List ref 3 d) 0 8))
             (doc-title "tests/fixtures/dot.png" d) (doc-blocks d)))
```
---
    ('image 2 1 "ff0000ff00ff00ff" "dot.png" ())

### a data: url in base64: a PNG an image, a page by its type, text without one; its title is data: and the type; another image type, or bad base64, is refused

```browse
(def png "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAAD0lEQVQI12P4z8DA8J8BAAf/Af8Jop8XAAAAAElFTkSuQmCC")
(def d (doc-load png))
(write (list (first d) (List ref 1 d) (List ref 2 d) (Bytes hex (list (List ref 3 d) 0 8)) (doc-title png d)
             (doc-load "data:text/markdown;charset=utf-8;base64,IyBIaQoKVGhlcmUu")
             (doc-load "data:;base64,IyBIaQoKVGhlcmUu")
             (doc-title "data:;base64,IyBIaQoKVGhlcmUu" (doc-load "data:;base64,IyBIaQoKVGhlcmUu"))
             (guard (e (e msg)) (doc-load "data:image/gif;base64,R0lGODlh"))
             (guard (e (e msg)) (doc-load "data:;base64,!!!!"))))
```
---
    ('image 2 1 "ff0000ff00ff00ff" "data:image/png" ('markdown ('heading 1 ("Hi")) ('paragraph ("There."))) ('text . "# Hi\n\nThere.") "data:text/plain" "an image this browser cannot show: image/gif" "a data: url whose base64 does not decode")

### a data: url not in base64 is percent-decoded: a page by its type, text without one; an image, or one with no comma, is refused

```browse
(write (list (doc-load "data:,hi%20there%21")
             (doc-load "data:text/markdown,%23%20Hi%0A%0AThere.")
             (doc-title "data:text/markdown,%23%20Hi" (doc-load "data:text/markdown,%23%20Hi"))
             (guard (e (e msg)) (doc-load "data:image/svg+xml,%3Csvg%3E"))
             (guard (e (e msg)) (doc-load "data:text/plain"))))
```
---
    (('text . "hi there!") ('markdown ('heading 1 ("Hi")) ('paragraph ("There."))) "Hi" "an image in a data: url not in base64: image/svg+xml" "a data: url with no comma")

## dump

### an image: its picture in half blocks and 24-bit colour

```browse
(write (browse-dump "tests/fixtures/dot.png" 40))
```
---
    "\x1b[0;38;2;255;0;0m▀\x1b[0;38;2;0;255;0m▀\x1b[0m\n"

### lynx's: link text led by its number, the references after

```browse
(write (browse-dump "tests/fixtures/index.md" 40))
```
---
    "Fixtures\n\nA [1]page and the [2]same page.\n\n• Italic and bold\n• [3]Back home\n\nReferences\n\n   1. tests/fixtures/sub/page.md\n   2. tests/fixtures/sub/page.md#second-part\n   3. tests/fixtures/index.md\n"

## html

### an HTML file: its title, its blocks as Markdown's, and its links resolved as Markdown's are

```browse
(def d (doc-load "tests/fixtures/page.html"))
(write (list (first d) (doc-title "tests/fixtures/page.html" d) (doc-blocks d)
             (doc-title "tests/fixtures/sub/page.md" (doc-load "tests/fixtures/sub/page.md"))))
```
---
    ('html "A Page & its title" (('heading 1 ("Fixture Page")) ('paragraph ("A " ('link "sub/page.md" () ("page")) " and " ('link "index.md" "home" ("home")) ", with " ('strong ("bold")) ", " ('emph ("italic")) " and " ('code "code") ".")) ('list #f () #t ((('paragraph ("one"))) (('paragraph ("two an image"))))) ('paragraph (('strong ("Name")) " | " ('strong ("Value")))) ('paragraph ("a | 1")) ('code-block "" "kept   as\n  written\n")) "A page")

### -dump of an HTML page: the links numbered and resolved against it

```browse
(write (browse-dump "tests/fixtures/page.html" 40))
```
---
    "Fixture Page\n\nA [1]page and [2]home, with bold, italic\nand code.\n\n• one\n• two an image\n\nName | Value\n\na | 1\n\nkept   as\n  written\n\nReferences\n\n   1. tests/fixtures/sub/page.md\n   2. tests/fixtures/index.md\n"
