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

## dump

### lynx's: link text led by its number, the references after

```browse
(write (browse-dump "tests/fixtures/index.md" 40))
```
---
    "Fixtures\n\nA [1]page and the [2]same page.\n\n• Italic and bold\n• [3]Back home\n\nReferences\n\n   1. tests/fixtures/sub/page.md\n   2. tests/fixtures/sub/page.md#second-part\n   3. tests/fixtures/index.md\n"
